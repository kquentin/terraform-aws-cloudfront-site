# terraform-aws-cloudfront-site

## What it does

- CloudFront distribution (IPv6, HTTP/2+3)
- Route53 records (alias or CNAME, alternatives)
- Response headers policy (HSTS, CSP, frame options, referrer policy, custom headers)
- Multiple origins (S3 with OAC, custom origins)
- Default and extra cache behaviors
- Lambda@Edge associations (via key-based indirection)
- CloudFront Function associations (default and extra behaviors, optional runtime config)
- Custom error responses
- Access logging
- WAF integration
- Price class control

ACM certificate must be managed externally and passed via `certificate_arn`.

## Usage

```hcl
module "site" {
  source = "github.com/kquentin/terraform-aws-cloudfront-site"

  certificate_arn = aws_acm_certificate.wildcard.arn
  domain_zone_id  = aws_route53_zone.main.zone_id
  oac_id          = aws_cloudfront_origin_access_control.this.id

  website_bucket = {
    arn                         = module.website.arn
    id                          = module.website.id
    bucket_regional_domain_name = module.website.bucket_regional_domain_name
  }

  config = jsondecode(file("config.json"))
}
```

See [examples/](examples/) for complete config.json files:
- [static.json](examples/static.json) — static website (S3 + CloudFront)
- [spa.json](examples/spa.json) — SPA with API proxy, runtime config, CSP, custom headers

### Lambda@Edge

Lambda@Edge associations use key-based indirection: reference a logical key in your config JSON, and pass the actual ARNs via `edge_lambda_arns`.

```json
{
  "default_behavior": {
    "lambda_function_associations": [
      {
        "event_type": "origin-request",
        "lambda_key": "rewrite",
        "include_body": false
      }
    ]
  }
}
```

```hcl
module "site" {
  # ...

  edge_lambda_arns = {
    rewrite = aws_lambda_function.rewrite.qualified_arn
  }
}
```

## Runtime config

When `runtime_environment_config` is set in config, a CloudFront Function serves `/runtime-config.js` with cache disabled. The response exposes the key/values as `window.__ENV__`.

In your JSON config:
```json
{
  "runtime_environment_config": {
    "API_URL": "https://api.example.com",
    "ENVIRONMENT": "production"
  }
}
```

In your app:
```html
<script src="/runtime-config.js"></script>
<script>
  console.log(window.__ENV__.API_URL);
</script>
```

## Inputs

| Name | Type | Default | Required |
|------|------|---------|----------|
| certificate_arn | string | | yes |
| domain_zone_id | string | | yes |
| oac_id | string | | yes |
| website_bucket | object | | yes |
| config | object | | yes |
| logs_bucket_domain_name | string | null | no |
| price_class | string | PriceClass_All | no |
| waf_arn | string | null | no |
| edge_lambda_arns | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| distribution_id | Distribution ID |
| distribution_arn | Distribution ARN |
| distribution_domain_name | Distribution domain name |
| distribution_hosted_zone_id | Distribution Route53 zone ID |
