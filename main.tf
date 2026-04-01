resource "aws_s3_bucket_policy" "website" {
  bucket = var.website_bucket.id
  policy = data.aws_iam_policy_document.this.json
}

resource "aws_cloudfront_response_headers_policy" "this" {
  name = "${var.config.name}-response-headers-policy"

  security_headers_config {
    strict_transport_security {
      override                   = var.config.security_headers_config.strict_transport_security.override
      include_subdomains         = var.config.security_headers_config.strict_transport_security.include_subdomains
      access_control_max_age_sec = var.config.security_headers_config.strict_transport_security.access_control_max_age_sec
      preload                    = var.config.security_headers_config.strict_transport_security.preload
    }

    content_type_options {
      override = var.config.security_headers_config.content_type_options.override
    }

    dynamic "content_security_policy" {
      for_each = var.config.security_headers_config.content_security_policy != null ? [var.config.security_headers_config.content_security_policy] : []
      content {
        override                = content_security_policy.value.override
        content_security_policy = content_security_policy.value.content_security_policy
      }
    }

    frame_options {
      override     = var.config.security_headers_config.frame_options.override
      frame_option = var.config.security_headers_config.frame_options.frame_option
    }

    referrer_policy {
      override        = var.config.security_headers_config.referrer_policy.override
      referrer_policy = var.config.security_headers_config.referrer_policy.referrer_policy
    }
  }

  dynamic "custom_headers_config" {
    for_each = var.config.custom_headers_config != null ? [1] : []

    content {
      dynamic "items" {
        for_each = var.config.custom_headers_config

        content {
          header   = items.value.header
          value    = items.value.value
          override = items.value.override
        }
      }
    }
  }
}

resource "aws_cloudfront_distribution" "this" {
  comment             = var.config.name
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = var.config.http_version
  default_root_object = "index.html"
  wait_for_deployment = true

  aliases     = local.domain_names
  price_class = var.price_class
  web_acl_id  = var.waf_arn

  viewer_certificate {
    acm_certificate_arn      = var.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  dynamic "origin" {
    for_each = values(local.origin_map)
    content {
      origin_id                = origin.value.origin_id
      domain_name              = origin.value.domain_name
      origin_access_control_id = origin.value.origin_access_control_id

      dynamic "custom_origin_config" {
        for_each = origin.value.custom_origin_config != null ? [1] : []

        content {
          http_port              = origin.value.custom_origin_config.http_port
          https_port             = origin.value.custom_origin_config.https_port
          origin_protocol_policy = origin.value.custom_origin_config.origin_protocol_policy
          origin_ssl_protocols   = origin.value.custom_origin_config.origin_ssl_protocols
        }
      }

      dynamic "custom_header" {
        for_each = origin.value.custom_headers

        content {
          name  = custom_header.value.name
          value = custom_header.value.value
        }
      }
    }
  }

  default_cache_behavior {
    target_origin_id       = local.resolved_default_behavior.target_origin_id
    viewer_protocol_policy = local.resolved_default_behavior.viewer_protocol_policy
    allowed_methods        = local.resolved_default_behavior.allowed_methods
    cached_methods         = local.resolved_default_behavior.cached_methods
    compress               = local.resolved_default_behavior.compress

    cache_policy_id            = local.resolved_default_behavior.cache_policy_id
    origin_request_policy_id   = local.resolved_default_behavior.origin_request_policy_id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.this.id

    min_ttl     = local.resolved_default_behavior.min_ttl
    default_ttl = local.resolved_default_behavior.default_ttl
    max_ttl     = local.resolved_default_behavior.max_ttl

    dynamic "forwarded_values" {
      for_each = local.resolved_default_behavior.forwarded_values != null ? [local.resolved_default_behavior.forwarded_values] : []

      content {
        query_string            = forwarded_values.value.query_string
        query_string_cache_keys = forwarded_values.value.query_string_cache_keys
        headers                 = forwarded_values.value.headers

        cookies {
          forward           = forwarded_values.value.cookies.forward
          whitelisted_names = forwarded_values.value.cookies.whitelisted_names
        }
      }
    }

    dynamic "lambda_function_association" {
      for_each = local.resolved_default_behavior.lambda_function_associations

      content {
        event_type   = lambda_function_association.value.event_type
        lambda_arn   = lambda_function_association.value.lambda_arn
        include_body = lambda_function_association.value.include_body != null ? lambda_function_association.value.include_body : false
      }
    }

    dynamic "function_association" {
      for_each = local.resolved_default_behavior.function_associations

      content {
        event_type   = function_association.value.event_type
        function_arn = function_association.value.function_arn
      }
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = local.resolved_extra_behaviors

    content {
      path_pattern           = ordered_cache_behavior.value.path_pattern
      target_origin_id       = ordered_cache_behavior.value.target_origin_id
      viewer_protocol_policy = ordered_cache_behavior.value.viewer_protocol_policy
      allowed_methods        = ordered_cache_behavior.value.allowed_methods
      cached_methods         = ordered_cache_behavior.value.cached_methods
      compress               = ordered_cache_behavior.value.compress

      cache_policy_id          = ordered_cache_behavior.value.cache_policy_id
      origin_request_policy_id = ordered_cache_behavior.value.origin_request_policy_id

      response_headers_policy_id = aws_cloudfront_response_headers_policy.this.id

      min_ttl     = ordered_cache_behavior.value.min_ttl
      default_ttl = ordered_cache_behavior.value.default_ttl
      max_ttl     = ordered_cache_behavior.value.max_ttl

      dynamic "forwarded_values" {
        for_each = ordered_cache_behavior.value.forwarded_values != null ? [ordered_cache_behavior.value.forwarded_values] : []

        content {
          query_string            = forwarded_values.value.query_string
          query_string_cache_keys = forwarded_values.value.query_string_cache_keys
          headers                 = forwarded_values.value.headers

          cookies {
            forward           = forwarded_values.value.cookies.forward
            whitelisted_names = forwarded_values.value.cookies.whitelisted_names
          }
        }
      }

      dynamic "lambda_function_association" {
        for_each = ordered_cache_behavior.value.lambda_function_associations != null ? ordered_cache_behavior.value.lambda_function_associations : []

        content {
          event_type   = lambda_function_association.value.event_type
          lambda_arn   = lambda_function_association.value.lambda_arn
          include_body = lambda_function_association.value.include_body != null ? lambda_function_association.value.include_body : false
        }
      }

      dynamic "function_association" {
        for_each = ordered_cache_behavior.value.function_associations != null ? ordered_cache_behavior.value.function_associations : []

        content {
          event_type   = function_association.value.event_type
          function_arn = function_association.value.function_arn
        }
      }
    }
  }

  dynamic "custom_error_response" {
    for_each = var.config.custom_error_responses != null ? var.config.custom_error_responses : []

    content {
      error_code            = custom_error_response.value.error_code
      response_code         = custom_error_response.value.response_code
      response_page_path    = custom_error_response.value.response_page_path
      error_caching_min_ttl = custom_error_response.value.error_caching_min_ttl
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  dynamic "logging_config" {
    for_each = var.logs_bucket_domain_name != null ? [1] : []
    content {
      bucket          = var.logs_bucket_domain_name
      prefix          = "${var.config.name}/"
      include_cookies = false
    }
  }

  tags = merge({ Name = var.config.name }, var.config.tags)
}
