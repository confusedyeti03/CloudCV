# AWS DynamoDB Tables
# Purpose: Serverless database for CV cache, projects cache, and visit analytics
#
# Table 1: visits
# - Records page visits for analytics
# - Partition key: page_id, Sort key: timestamp
# - TTL enabled: records auto-delete after 90 days
#
# Table 2: cv_cache
# - Caches CV HTML by language
# - Partition key: language (ca, es, en)
#
# Table 3: projects_cache
# - Caches portfolio projects by type
# - Partition key: project_type (personal, challenges, etc.)

# DynamoDB Table 1: Visits
resource "aws_dynamodb_table" "visits" {
  name           = "${var.project_name}-visits"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "page_id"
  range_key      = "timestamp"

  attribute {
    name = "page_id"
    type = "S"  # String
  }

  attribute {
    name = "timestamp"
    type = "N"  # Number (unix timestamp)
  }

  ttl {
    attribute_name = "expiration_time"
    enabled        = true
  }

  tags = {
    Name        = "${var.project_name}-visits-table"
    Environment = "production"
  }
}

# DynamoDB Table 2: CV Cache
resource "aws_dynamodb_table" "cv_cache" {
  name           = "${var.project_name}-cv-cache"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "language"

  attribute {
    name = "language"
    type = "S"  # String (ca, es, en)
  }

  ttl {
    attribute_name = "expiration_time"
    enabled        = true
  }

  tags = {
    Name        = "${var.project_name}-cv-cache-table"
    Environment = "production"
  }
}

# DynamoDB Table 3: Projects Cache
resource "aws_dynamodb_table" "projects_cache" {
  name           = "${var.project_name}-projects-cache"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "project_type"

  attribute {
    name = "project_type"
    type = "S"  # String (personal, challenges, etc.)
  }

  ttl {
    attribute_name = "expiration_time"
    enabled        = true
  }

  tags = {
    Name        = "${var.project_name}-projects-cache-table"
    Environment = "production"
  }
}

# CloudWatch Alarms for DynamoDB

# Alarm: DynamoDB throttling on visits table
resource "aws_cloudwatch_metric_alarm" "dynamodb_throttle_visits" {
  alarm_name          = "${var.project_name}-dynamodb-visits-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ConsumedWriteCapacityUnits"
  namespace           = "AWS/DynamoDB"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alert when DynamoDB visits table is throttled"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = aws_dynamodb_table.visits.name
  }
}

# Alarm: DynamoDB user errors
resource "aws_cloudwatch_metric_alarm" "dynamodb_user_errors" {
  alarm_name          = "${var.project_name}-dynamodb-user-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UserErrors"
  namespace           = "AWS/DynamoDB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Alert when DynamoDB user errors exceed 5"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = aws_dynamodb_table.visits.name
  }
}

# Outputs
output "visits_table_name" {
  description = "Name of DynamoDB visits table"
  value       = aws_dynamodb_table.visits.name
}

output "cv_cache_table_name" {
  description = "Name of DynamoDB CV cache table"
  value       = aws_dynamodb_table.cv_cache.name
}

output "projects_cache_table_name" {
  description = "Name of DynamoDB projects cache table"
  value       = aws_dynamodb_table.projects_cache.name
}
