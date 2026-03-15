resource "aws_acm_certificate" "this" {
  provider = aws.us_east_1

  domain_name               = var.config.domain_alias
  subject_alternative_names = local.alternative_domain_names
  validation_method         = "DNS"

  tags = var.config.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "validation_domain" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = var.domain_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "this" {
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.validation_domain : record.fqdn]
}

resource "aws_route53_record" "cloudfront_dns_alias" {
  zone_id = var.domain_zone_id
  name    = var.config.domain_alias
  type    = var.config.record_type
  ttl     = local.is_alias_record ? null : 300
  records = local.is_alias_record ? null : [aws_cloudfront_distribution.this.domain_name]

  dynamic "alias" {
    for_each = local.is_alias_record ? [1] : []
    content {
      name                   = aws_cloudfront_distribution.this.domain_name
      zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
      evaluate_target_health = false
    }
  }
}

resource "aws_route53_record" "alternatives_domains_dns_alias" {
  for_each = toset(local.alternative_domain_names)

  zone_id = var.domain_zone_id
  name    = each.value
  type    = "CNAME"
  ttl     = 300
  records = [aws_cloudfront_distribution.this.domain_name]
}
