# AWS DynamoDB Tables
# Purpose: Serverless database for visit analytics
#
# Table: visits
# - Aggregate visit counter per page (sort key 0, never expires)
# - Partition key: page_id, Sort key: timestamp
# - TTL enabled for any future per-visit items

resource "aws_dynamodb_table" "visits" {
  name         = "${var.project_name}-visits"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "page_id"
  range_key    = "timestamp"

  attribute {
    name = "page_id"
    type = "S" # String
  }

  attribute {
    name = "timestamp"
    type = "N" # Number (unix timestamp)
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

# CloudWatch Alarms for DynamoDB

# Alarm: DynamoDB write throttling on visits table
resource "aws_cloudwatch_metric_alarm" "dynamodb_throttle_visits" {
  alarm_name          = "${var.project_name}-dynamodb-visits-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "WriteThrottleEvents"
  namespace           = "AWS/DynamoDB"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alert when DynamoDB visits table is throttled"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]

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
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    TableName = aws_dynamodb_table.visits.name
  }
}

# Outputs
output "visits_table_name" {
  description = "Name of DynamoDB visits table"
  value       = aws_dynamodb_table.visits.name
}
