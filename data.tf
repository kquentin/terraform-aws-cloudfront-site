data "aws_cloudfront_cache_policy" "this" {
  for_each = toset(local.cache_policy_names)

  name = each.value
}

data "aws_cloudfront_origin_request_policy" "this" {
  for_each = toset(local.origin_request_policy_names)

  name = each.value
}

data "aws_iam_policy_document" "this" {
  statement {
    effect = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${var.website_bucket.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}
