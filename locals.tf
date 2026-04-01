locals {
  alternative_domain_names = var.config.alternative_domain_names != null ? var.config.alternative_domain_names : []
  domain_names             = concat([var.config.domain_alias], local.alternative_domain_names)

  is_alias_record = var.config.record_type != "CNAME"

  runtime_config_enabled           = var.config.runtime_environment_config != null
  runtime_config_cache_policy_name = "Managed-CachingDisabled"
  runtime_config_function_code = templatefile(
    "${path.module}/templates/runtime_config/function.js.tftpl",
    { config = var.config.runtime_environment_config != null ? var.config.runtime_environment_config : {} }
  )

  extra_behaviors = var.config.extra_behaviors != null ? var.config.extra_behaviors : []

  # Resolve policy names to IDs via data sources (see data.tf).
  # Collect all names used across behaviors and strip nulls from optional fields.
  # Behaviors using forwarded_values have null policy names, which compact() removes.
  # Then deduplicate so each data source is fetched only once.

  all_cache_policy_names = concat(
    [var.config.default_behavior.cache_policy_name],
    [for b in local.extra_behaviors : b.cache_policy_name],
    local.runtime_config_enabled ? [local.runtime_config_cache_policy_name] : []
  )

  all_origin_request_policy_names = concat(
    [var.config.default_behavior.origin_request_policy_name],
    [for b in local.extra_behaviors : b.origin_request_policy_name]
  )

  cache_policy_names          = distinct(compact(local.all_cache_policy_names))
  origin_request_policy_names = distinct(compact(local.all_origin_request_policy_names))

  s3_origin = {
    key                      = "s3-origin"
    origin_id                = "s3-origin"
    domain_name              = var.website_bucket.bucket_regional_domain_name
    origin_access_control_id = var.oac_id
    custom_origin_config     = null
    custom_headers           = []
  }

  extra_origins = { for origin in var.config.origins : origin.key => {
    key                      = origin.key
    origin_id                = origin.origin_id != null ? origin.origin_id : origin.key
    domain_name              = origin.domain_name
    origin_access_control_id = null
    custom_origin_config     = origin.custom_origin_config
    custom_headers           = origin.custom_headers != null ? origin.custom_headers : []
  } }

  origin_map = merge({ "s3-origin" = local.s3_origin }, local.extra_origins)

  resolved_default_behavior = {
    target_origin_id         = local.origin_map[var.config.default_behavior.target_origin_key].origin_id
    viewer_protocol_policy   = var.config.default_behavior.viewer_protocol_policy
    allowed_methods          = var.config.default_behavior.allowed_methods
    cached_methods           = var.config.default_behavior.cached_methods
    compress                 = var.config.default_behavior.compress
    cache_policy_id          = var.config.default_behavior.forwarded_values == null ? data.aws_cloudfront_cache_policy.this[var.config.default_behavior.cache_policy_name].id : null
    origin_request_policy_id = var.config.default_behavior.forwarded_values == null ? try(data.aws_cloudfront_origin_request_policy.this[var.config.default_behavior.origin_request_policy_name].id, null) : null
    forwarded_values         = var.config.default_behavior.forwarded_values
    min_ttl                  = var.config.default_behavior.min_ttl
    default_ttl              = var.config.default_behavior.default_ttl
    max_ttl                  = var.config.default_behavior.max_ttl
    lambda_function_associations = [for assoc in (var.config.default_behavior.lambda_function_associations != null ? var.config.default_behavior.lambda_function_associations : []) : {
      event_type   = assoc.event_type
      lambda_arn   = var.edge_lambda_arns[assoc.lambda_key]
      include_body = assoc.include_body
    }]
    function_associations = [for assoc in (var.config.default_behavior.function_associations != null ? var.config.default_behavior.function_associations : []) : {
      event_type   = assoc.event_type
      function_arn = var.cloudfront_function_arns[assoc.function_key]
    }]
  }

  resolved_extra_behaviors = concat(
    local.runtime_config_enabled ? [{
      path_pattern                 = "/runtime-config.js"
      target_origin_id             = local.origin_map[var.config.default_behavior.target_origin_key].origin_id
      viewer_protocol_policy       = "redirect-to-https"
      allowed_methods              = ["GET", "HEAD"]
      cached_methods               = ["GET", "HEAD"]
      compress                     = false
      cache_policy_id              = data.aws_cloudfront_cache_policy.this[local.runtime_config_cache_policy_name].id
      origin_request_policy_id     = null
      forwarded_values             = null
      min_ttl                      = null
      default_ttl                  = null
      max_ttl                      = null
      lambda_function_associations = []
      function_associations = [{
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.runtime_config[0].arn
      }]
    }] : [],
    [
      for behavior in local.extra_behaviors : {
        path_pattern             = behavior.path_pattern
        target_origin_id         = local.origin_map[behavior.target_origin_key].origin_id
        viewer_protocol_policy   = behavior.viewer_protocol_policy
        allowed_methods          = behavior.allowed_methods
        cached_methods           = behavior.cached_methods
        compress                 = behavior.compress
        cache_policy_id          = behavior.forwarded_values == null ? data.aws_cloudfront_cache_policy.this[behavior.cache_policy_name].id : null
        origin_request_policy_id = behavior.forwarded_values == null ? try(data.aws_cloudfront_origin_request_policy.this[behavior.origin_request_policy_name].id, null) : null
        forwarded_values         = behavior.forwarded_values
        min_ttl                  = behavior.min_ttl
        default_ttl              = behavior.default_ttl
        max_ttl                  = behavior.max_ttl
        lambda_function_associations = [for assoc in (behavior.lambda_function_associations != null ? behavior.lambda_function_associations : []) : {
          event_type   = assoc.event_type
          lambda_arn   = var.edge_lambda_arns[assoc.lambda_key]
          include_body = assoc.include_body
        }]
        function_associations = [for assoc in (behavior.function_associations != null ? behavior.function_associations : []) : {
          event_type   = assoc.event_type
          function_arn = var.cloudfront_function_arns[assoc.function_key]
        }]
      }
    ]
  )
}
