# AWS Security Services
# CloudTrail: Audit all AWS API calls (logs to dedicated S3 bucket)
# KMS: Encryption key management

# KMS Key for S3 bucket encryption
resource "aws_kms_key" "s3_encryption" {
  description             = "KMS key for S3 bucket encryption (CloudCV)"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudTrail to encrypt logs"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "kms:GenerateDataKey"
        Resource = "*"
        Condition = {
          StringLike = {
            "kms:EncryptionContext:aws:cloudtrail:arn" = "arn:aws:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/*"
          }
        }
      },
      {
        Sid    = "Allow CloudTrail to describe key"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "kms:DescribeKey"
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-s3-key"
  }
}

resource "aws_kms_alias" "s3_encryption" {
  name          = "alias/${var.project_name}-s3"
  target_key_id = aws_kms_key.s3_encryption.key_id
}

# S3 Bucket for CloudTrail logs
# CloudTrail requires a dedicated bucket for audit logs
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = "${var.project_name}-cloudtrail-logs-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "${var.project_name}-cloudtrail-logs"
    Environment = "production"
    Purpose     = "CloudTrail audit logs"
  }
}

# Block all public access to CloudTrail bucket
resource "aws_s3_bucket_public_access_block" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for audit trail integrity
resource "aws_s3_bucket_versioning" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption with KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_encryption.arn
    }
  }
}

# S3 Bucket policy to allow CloudTrail to write logs
resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_logs.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# CloudTrail for audit logging
# Logs all AWS API calls to S3
resource "aws_cloudtrail" "main" {
  name                          = "${var.project_name}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  depends_on                    = [aws_s3_bucket_policy.cloudtrail_logs]
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.s3_encryption.arn

  # TODO: Enable event selectors in FASE 6 with proper ARN format
  # For MVP, track all management events only (default behavior)

  tags = {
    Name        = "${var.project_name}-audit-trail"
    Environment = "production"
  }
}

# Outputs
output "cloudtrail_arn" {
  description = "ARN of CloudTrail"
  value       = aws_cloudtrail.main.arn
}

output "cloudtrail_logs_bucket" {
  description = "S3 bucket storing CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail_logs.id
}

output "kms_key_id" {
  description = "KMS key ID for S3 encryption"
  value       = aws_kms_key.s3_encryption.id
}

output "kms_key_arn" {
  description = "KMS key ARN for S3 encryption"
  value       = aws_kms_key.s3_encryption.arn
}
