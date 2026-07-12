# SNS Topic for CloudWatch alarm notifications
# All Lambda/DynamoDB alarms publish here; subscription delivers by email.
# NOTE: the email subscription must be confirmed manually (AWS sends a
# confirmation link to admin_email after apply).

resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"

  tags = {
    Name        = "${var.project_name}-alerts"
    Environment = "production"
  }
}

resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.admin_email
}

output "alerts_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarm notifications"
  value       = aws_sns_topic.alerts.arn
}
