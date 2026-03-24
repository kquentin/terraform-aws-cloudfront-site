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
