# S3 Bucket for CloudCV Static Assets
# This bucket stores all static content served via CloudFront
# - HTML files (index.html, CV pages)
# - CSS stylesheets (minified)
# - JavaScript bundles (minified)
# - Images (WebP optimized)
# - Assets (badges, certificates, photos)
#
# Access: PRIVATE (CloudFront OAI only)
# Versioning: Enabled (allow rollback)
# Encryption: AES-256 (default, AWS managed)

resource "aws_s3_bucket" "assets" {
  bucket = "${var.project_name}-assets-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "${var.project_name}-assets"
    Environment = "production"
    Purpose     = "Static content for CloudFront"
  }
}

# Enable ACLs to allow CloudFront to write logs (deferred to FASE 6)
# resource "aws_s3_bucket_acl" "assets" {
#   bucket = aws_s3_bucket.assets.id
#   acl    = "log-delivery-write"
# }

# Enable versioning for asset management and rollback capability
resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Block all public access (CloudFront will access via OAI)
resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable server-side encryption with AES-256 (default AWS managed key)
resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle rule: delete old versions after 30 days (reduce storage costs)
resource "aws_s3_bucket_lifecycle_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# Enable access logging for audit trail (optional, ~$0.05/mo for small portfolio)
resource "aws_s3_bucket_logging" "assets" {
  bucket = aws_s3_bucket.assets.id

  target_bucket = aws_s3_bucket.assets.id
  target_prefix = "access-logs/"
}

# CORS configuration for assets accessed from different origins
resource "aws_s3_bucket_cors_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["https://${var.domain}", "https://www.${var.domain}"]
    expose_headers  = ["ETag", "x-amz-version-id"]
    max_age_seconds = 3600
  }
}

# S3 bucket policy: Allow CloudFront OAI to read objects
resource "aws_s3_bucket_policy" "assets" {
  bucket = aws_s3_bucket.assets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAI"
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.s3.iam_arn
        }
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.assets.arn}/*"
      },
      {
        Sid    = "AllowPublicReadCVPDF"
        Effect = "Allow"
        Principal = "*"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.assets.arn}/cv/*.pdf"
      }
    ]
  })
}

# Output bucket name for use in other resources
output "s3_bucket_name" {
  description = "Name of the S3 bucket storing CloudCV assets"
  value       = aws_s3_bucket.assets.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.assets.arn
}

output "s3_bucket_region" {
  description = "AWS region where S3 bucket is located"
  value       = aws_s3_bucket.assets.region
}
