# terraform-aws-cloudfront-site

## What it does

- CloudFront distribution (IPv6, HTTP/2+3)
- ACM certificate with DNS validation
- Route53 records (alias or CNAME, alternatives)
- Response headers policy (HSTS, CSP, frame options, referrer policy, custom headers)
- Multiple origins (S3 with OAC, custom origins)
- Default and extra cache behaviors
- Lambda@Edge associations
- CloudFront Function associations (default and extra behaviors, optional runtime config)
- Custom error responses
- Access logging
- WAF integration
- Price class control

## Usage

```hcl
module "site" {
  source = "github.com/kquentin/terraform-aws-cloudfront-site"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  domain_zone_id = aws_route53_zone.main.zone_id
  oac_id         = aws_cloudfront_origin_access_control.this.id

  website_bucket = {
    bucket_regional_domain_name = module.website.bucket_regional_domain_name
  }

  config = jsondecode(file("config.json"))
}
```

See [examples/](examples/) for complete config.json files:
- [static.json](examples/static.json) — static website (S3 + CloudFront)
- [spa.json](examples/spa.json) — SPA with API proxy, runtime config, CSP, custom headers

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
| domain_zone_id | string | | yes |
| oac_id | string | | yes |
| website_bucket | object | | yes |
| config | object | | yes |
| logs_bucket | object | null | no |
| price_class | string | PriceClass_All | no |
| waf_arn | string | null | no |

## Outputs

| Name | Description |
|------|-------------|
| distribution_id | Distribution ID |
| distribution_arn | Distribution ARN |
| distribution_domain_name | Distribution domain name |
| distribution_hosted_zone_id | Distribution Route53 zone ID |
