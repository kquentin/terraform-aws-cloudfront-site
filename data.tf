data "aws_cloudfront_cache_policy" "this" {
  for_each = toset(local.cache_policy_names)

  name = each.value
}

data "aws_cloudfront_origin_request_policy" "this" {
  for_each = toset(local.origin_request_policy_names)

  name = each.value
}
