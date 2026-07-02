# CloudFront Origin Access Identity (OAI)
# This allows CloudFront to access S3 objects without making bucket public
# Security principle: Least privilege access

resource "aws_cloudfront_origin_access_identity" "s3" {
  comment = "OAI for ${var.project_name} S3 bucket"
}

output "cloudfront_oai_iam_arn" {
  description = "IAM ARN of CloudFront OAI (for S3 bucket policy)"
  value       = aws_cloudfront_origin_access_identity.s3.iam_arn
}

# CloudFront Distribution for static content
# Serves HTML, CSS, JS, and images from S3 via CDN
# Features:
# - Global edge locations (200+ cities)
# - Automatic compression (Gzip, Brotli)
# - Cache optimization (1 day TTL for static assets)
# - HTTPS only (HTTP redirects to HTTPS)
# - Custom domain support (lnoval.dev)
# - Free SSL/TLS via ACM

resource "aws_cloudfront_distribution" "static" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "CloudCV static content CDN"
  price_class         = "PriceClass_100" # US, Europe, Asia (best price/coverage balance)
  web_acl_id          = aws_wafv2_web_acl.cloudfront.arn

  origin {
    domain_name = aws_s3_bucket.assets.bucket_regional_domain_name
    origin_id   = "S3Assets"

    # Use OAI to access S3 privately (no public bucket access required)
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.s3.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    target_origin_id = "S3Assets"
    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id = aws_cloudfront_cache_policy.static.id

    # HTTP to HTTPS redirect
    viewer_protocol_policy = "redirect-to-https"

    # Compress response automatically (Gzip, Brotli)
    compress = true
  }

  # Cache behavior for index.html (no cache, always fresh)
  # This ensures new deployments are immediately visible
  ordered_cache_behavior {
    target_origin_id = "S3Assets"
    path_pattern ="/index.html"
    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id = aws_cloudfront_cache_policy.no_cache.id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  # Cache behavior for CV pages (no cache)
  ordered_cache_behavior {
    target_origin_id = "S3Assets"
    path_pattern ="/cv/*"
    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id = aws_cloudfront_cache_policy.no_cache.id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  # Cache behavior for portfolio pages (short cache)
  ordered_cache_behavior {
    target_origin_id = "S3Assets"
    path_pattern ="/portfolio/*"
    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id = aws_cloudfront_cache_policy.short_cache.id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  # Cache behavior for static assets: CSS, JS, images (long cache)
  ordered_cache_behavior {
    target_origin_id = "S3Assets"
    path_pattern ="/assets/*"
    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id = aws_cloudfront_cache_policy.long_cache.id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  ordered_cache_behavior {
    target_origin_id = "S3Assets"
    path_pattern ="/styles/*"
    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id = aws_cloudfront_cache_policy.long_cache.id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  ordered_cache_behavior {
    target_origin_id = "S3Assets"
    path_pattern ="*.css"
    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id = aws_cloudfront_cache_policy.long_cache.id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  ordered_cache_behavior {
    target_origin_id = "S3Assets"
    path_pattern ="*.js"
    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id = aws_cloudfront_cache_policy.long_cache.id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  ordered_cache_behavior {
    target_origin_id = "S3Assets"
    path_pattern ="*.png"
    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id = aws_cloudfront_cache_policy.long_cache.id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  ordered_cache_behavior {
    target_origin_id = "S3Assets"
    path_pattern ="*.jpg"
    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id = aws_cloudfront_cache_policy.long_cache.id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  ordered_cache_behavior {
    target_origin_id = "S3Assets"
    path_pattern ="*.webp"
    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id = aws_cloudfront_cache_policy.long_cache.id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  # FASE 5: Use ACM certificate for custom domain
  aliases = [var.domain, "www.${var.domain}"]

  viewer_certificate {
    acm_certificate_arn            = aws_acm_certificate.cloudfront.arn
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.2_2021"
    cloudfront_default_certificate = false
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # CloudFront logging (deferred to FASE 6 - requires ACL configuration)
  # logging_config {
  #   include_cookies = false
  #   bucket          = aws_s3_bucket.assets.bucket_regional_domain_name
  #   prefix          = "cloudfront-logs/"
  # }

  tags = {
    Name        = "${var.project_name}-cdn"
    Environment = "production"
  }
}

# CloudFront Cache Policies
# These control how CloudFront caches content

# Cache policy for static assets (1 day TTL)
# Long cache for CSS, JS, images that change infrequently
resource "aws_cloudfront_cache_policy" "long_cache" {
  name            = "${var.project_name}-long-cache"
  comment         = "1 day cache for static assets"
  default_ttl     = 86400  # 1 day
  max_ttl         = 86400  # 1 day
  min_ttl         = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
    cookies_config {
      cookie_behavior = "none"
    }
  }
}

# Cache policy for content that should be cached for shorter periods
# (portfolio, project pages that might change weekly)
resource "aws_cloudfront_cache_policy" "short_cache" {
  name            = "${var.project_name}-short-cache"
  comment         = "1 hour cache for dynamic content"
  default_ttl     = 3600   # 1 hour
  max_ttl         = 3600   # 1 hour
  min_ttl         = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
    cookies_config {
      cookie_behavior = "none"
    }
  }
}

# Cache policy for static content (no cache)
# For index.html, CV pages (always fetch fresh from S3)
resource "aws_cloudfront_cache_policy" "no_cache" {
  name            = "${var.project_name}-no-cache"
  comment         = "No cache for HTML pages (always fresh)"
  default_ttl     = 0
  max_ttl         = 0
  min_ttl         = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
    cookies_config {
      cookie_behavior = "none"
    }
  }
}

# Cache policy for general static content (default)
# Medium cache strategy
resource "aws_cloudfront_cache_policy" "static" {
  name            = "${var.project_name}-static-cache"
  comment         = "Default cache policy for static content"
  default_ttl     = 3600   # 1 hour
  max_ttl         = 86400  # 1 day
  min_ttl         = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
    cookies_config {
      cookie_behavior = "none"
    }
  }
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain"
  value       = aws_cloudfront_distribution.static.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (for cache invalidation)"
  value       = aws_cloudfront_distribution.static.id
}
