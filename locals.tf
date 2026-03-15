locals {
  alternative_domain_names = coalesce(var.config.alternative_domain_names, [])
  cloudfront_domains       = concat([var.config.domain_alias], local.alternative_domain_names)

  is_alias_record = var.config.record_type != "CNAME"

  runtime_config_enabled           = var.config.runtime_environment_config != null
  runtime_config_cache_policy_name = "Managed-CachingDisabled"
  runtime_config_function_code = templatefile(
    "${path.module}/templates/runtime_config/function.js.tftpl",
    { config = coalesce(var.config.runtime_environment_config, {}) }
  )

  extra_behaviors = coalesce(var.config.extra_behaviors, [])

  # Resolve policy names to IDs via data sources (see data.tf).
  # Collect all names used across behaviors and strip nulls from optional fields.
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

  origin_map = { for origin in var.config.origins : origin.key => merge(origin, {
    origin_id                = coalesce(origin.origin_id, origin.key)
    domain_name              = coalesce(origin.domain_name, var.website_bucket.bucket_regional_domain_name)
    origin_access_control_id = origin.custom_origin_config != null ? null : var.oac_id
  }) }

  resolved_default_behavior = {
    target_origin_id             = local.origin_map[var.config.default_behavior.target_origin_key].origin_id
    viewer_protocol_policy       = var.config.default_behavior.viewer_protocol_policy
    allowed_methods              = var.config.default_behavior.allowed_methods
    cached_methods               = var.config.default_behavior.cached_methods
    compress                     = var.config.default_behavior.compress
    cache_policy_id              = data.aws_cloudfront_cache_policy.this[var.config.default_behavior.cache_policy_name].id
    origin_request_policy_id     = try(data.aws_cloudfront_origin_request_policy.this[var.config.default_behavior.origin_request_policy_name].id, null)
    lambda_function_associations = coalesce(var.config.default_behavior.lambda_function_associations, [])
    function_associations        = coalesce(var.config.default_behavior.function_associations, [])
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
      lambda_function_associations = []
      function_associations = [{
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.runtime_config[0].arn
      }]
    }] : [],
    [
      for behavior in local.extra_behaviors : {
        path_pattern                 = behavior.path_pattern
        target_origin_id             = local.origin_map[behavior.target_origin_key].origin_id
        viewer_protocol_policy       = behavior.viewer_protocol_policy
        allowed_methods              = behavior.allowed_methods
        cached_methods               = behavior.cached_methods
        compress                     = behavior.compress
        cache_policy_id              = data.aws_cloudfront_cache_policy.this[behavior.cache_policy_name].id
        origin_request_policy_id     = try(data.aws_cloudfront_origin_request_policy.this[behavior.origin_request_policy_name].id, null)
        lambda_function_associations = coalesce(behavior.lambda_function_associations, [])
        function_associations        = null
      }
    ]
  )
}
