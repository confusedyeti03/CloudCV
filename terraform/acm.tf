# AWS Certificate Manager (ACM)
# Free SSL/TLS certificate for CloudFront
# Features:
# - Auto-renewal (AWS manages renewal before expiry)
# - Wildcard support (*.lnoval.dev + lnoval.dev)
# - DNS validation (via Cloudflare)
# - No per-certificate fees

resource "aws_acm_certificate" "main" {
  domain_name       = var.domain
  validation_method = "DNS"

  subject_alternative_names = [
    "www.${var.domain}"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-cert"
    Environment = "production"
  }
}

# CloudFront requires ACM certificates in us-east-1
# If deploying outside us-east-1, must create cert in us-east-1
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# Certificate for CloudFront (in us-east-1)
resource "aws_acm_certificate" "cloudfront" {
  provider          = aws.us_east_1
  domain_name       = var.domain
  validation_method = "DNS"

  subject_alternative_names = [
    "www.${var.domain}"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-cert-cloudfront"
    Environment = "production"
  }
}

# DNS validation records
# CloudFront cert validation (us-east-1)
resource "aws_acm_certificate_validation" "cloudfront" {
  provider        = aws.us_east_1
  certificate_arn = aws_acm_certificate.cloudfront.arn

  # Note: In production, add validation records to Cloudflare DNS
  # This is handled manually or via Route 53 if migrating DNS to AWS

  timeouts {
    create = "5m"
  }
}

# Local validation (for regional cert if needed)
resource "aws_acm_certificate_validation" "main" {
  certificate_arn = aws_acm_certificate.main.arn

  timeouts {
    create = "5m"
  }

  depends_on = [aws_acm_certificate.main]
}

output "acm_certificate_arn" {
  description = "ARN of ACM certificate for CloudFront"
  value       = aws_acm_certificate.cloudfront.arn
}

output "acm_certificate_domain_validation_options" {
  description = "Domain validation options (for DNS record creation)"
  value       = aws_acm_certificate.cloudfront.domain_validation_options
}

output "cloudfront_certificate_arn" {
  description = "ACM Certificate ARN for CloudFront distribution"
  value       = aws_acm_certificate.cloudfront.arn
}
