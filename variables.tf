variable "domain_zone_id" {
  type        = string
  description = "Route53 hosted zone ID for DNS records."
}

variable "oac_id" {
  type        = string
  description = "CloudFront Origin Access Control ID for S3 origins."
}

variable "website_bucket" {
  type = object({
    arn                         = string
    id                          = string
    bucket_regional_domain_name = string
  })
  description = "Website S3 bucket."
}

variable "logs_bucket" {
  type = object({
    bucket_domain_name = string
  })
  description = "Logs S3 bucket. If null, access logging is disabled."
  default     = null
}

variable "price_class" {
  type        = string
  description = "CloudFront price class to control distribution region coverage."
  default     = "PriceClass_All"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "Allowed values: PriceClass_100, PriceClass_200, PriceClass_All."
  }
}

variable "waf_arn" {
  type        = string
  description = "ARN of a WAF ACL to attach to CloudFront."
  default     = null
}

variable "config" {
  description = "Full site configuration loaded from JSON."

  type = object({
    name = string
    tags = map(string)

    domain_alias             = string
    record_type              = string
    alternative_domain_names = optional(list(string))

    http_version = optional(string, "http2and3")

    origins = list(object({
      key         = string
      origin_id   = optional(string)
      domain_name = optional(string)
      custom_origin_config = optional(object({
        http_port              = number
        https_port             = number
        origin_protocol_policy = string
        origin_ssl_protocols   = list(string)
      }))
    }))

    default_behavior = object({
      target_origin_key          = string
      viewer_protocol_policy     = string
      allowed_methods            = list(string)
      cached_methods             = list(string)
      compress                   = optional(bool, false)
      cache_policy_name          = optional(string)
      origin_request_policy_name = optional(string)
      min_ttl                    = optional(number)
      default_ttl                = optional(number)
      max_ttl                    = optional(number)
      forwarded_values = optional(object({
        query_string            = bool
        query_string_cache_keys = optional(list(string))
        headers                 = optional(list(string))
        cookies = object({
          forward           = string
          whitelisted_names = optional(list(string))
        })
      }))
      lambda_function_associations = optional(list(object({
        event_type   = string
        lambda_arn   = string
        include_body = optional(bool)
      })))
      function_associations = optional(list(object({
        event_type   = string
        function_arn = string
      })))
    })

    extra_behaviors = optional(list(object({
      path_pattern               = string
      target_origin_key          = string
      viewer_protocol_policy     = string
      allowed_methods            = list(string)
      cached_methods             = list(string)
      compress                   = optional(bool, false)
      cache_policy_name          = optional(string)
      origin_request_policy_name = optional(string)
      min_ttl                    = optional(number)
      default_ttl                = optional(number)
      max_ttl                    = optional(number)
      forwarded_values = optional(object({
        query_string            = bool
        query_string_cache_keys = optional(list(string))
        headers                 = optional(list(string))
        cookies = object({
          forward           = string
          whitelisted_names = optional(list(string))
        })
      }))
      lambda_function_associations = optional(list(object({
        event_type   = string
        lambda_arn   = string
        include_body = optional(bool)
      })))
    })))

    custom_error_responses = optional(list(object({
      error_code            = number
      response_code         = optional(number)
      response_page_path    = optional(string)
      error_caching_min_ttl = optional(number)
    })))

    security_headers_config = object({
      strict_transport_security = object({
        override                   = bool
        include_subdomains         = bool
        access_control_max_age_sec = number
        preload                    = bool
      })
      content_type_options = object({
        override = bool
      })
      content_security_policy = optional(object({
        override                = bool
        content_security_policy = string
      }))
      frame_options = object({
        override     = bool
        frame_option = string
      })
      referrer_policy = object({
        override        = bool
        referrer_policy = string
      })
    })

    custom_headers_config = optional(list(object({
      header   = string
      value    = string
      override = bool
    })))

    runtime_environment_config = optional(map(string))
  })

}

