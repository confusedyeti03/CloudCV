# AWS Certificate Manager (ACM)
# FASE 5: Enable HTTPS with custom domain
# Free SSL/TLS certificate for CloudFront
# Features:
# - Auto-renewal (AWS manages renewal before expiry)
# - Wildcard support (*.lnoval.dev + lnoval.dev)
# - DNS validation (via Cloudflare)
# - No per-certificate fees

# CloudFront requires ACM certificates in us-east-1
# Provider "aws.us_east_1" is defined in providers.tf

# Certificate for CloudFront (in us-east-1)
# DNS validation via Cloudflare (manual step required)
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

# Output validation records for manual DNS setup via Cloudflare
output "acm_certificate_domain_validation_options" {
  description = "Domain validation options - add these CNAME records to Cloudflare DNS"
  value       = aws_acm_certificate.cloudfront.domain_validation_options
}

output "acm_certificate_arn" {
  description = "ARN of ACM certificate for CloudFront"
  value       = aws_acm_certificate.cloudfront.arn
}
