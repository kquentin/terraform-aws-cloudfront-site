resource "aws_cloudfront_function" "runtime_config" {
  count = local.runtime_config_enabled ? 1 : 0

  name    = "${var.config.name}-runtime-config"
  runtime = "cloudfront-js-2.0"
  code    = local.runtime_config_function_code
  comment = "Serves runtime-config.js for ${var.config.name}"
}
