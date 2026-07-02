# AWS WAF (Web Application Firewall)
# Protects CloudFront from common web attacks
# Rules: SQL injection, XSS, rate limiting, known bad inputs
# Cost: $5/month + $0.60/million requests

# WAF Web ACL for CloudFront
resource "aws_wafv2_web_acl" "cloudfront" {
  name        = "${var.project_name}-waf-cloudfront"
  description = "WAF for CloudFront CDN - Protects against common web attacks"
  scope       = "CLOUDFRONT"
  default_action {
    allow {}
  }

  # Rule 1: AWS Managed Rules - Common Rule Set
  # Blocks SQL injection, XSS, command injection, etc.
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 0

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        # Exclude specific rules if needed
        # rule_action_override {
        #   name = "SizeRestrictions_BODY"
        #   action_to_use {
        #     count {}
        #   }
        # }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: AWS Managed Rules - Known Bad Inputs
  # Blocks patterns of known malicious input
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # Rule 3: Rate Limiting
  # Max 2000 requests per 5 minutes per IP
  rule {
    name     = "RateLimitingRule"
    priority = 2

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitingRule"
      sampled_requests_enabled   = true
    }
  }

  # Rule 4: Geo IP Blocking (optional)
  # Allow only traffic from specified countries
  # Blocked countries: CN (China), RU (Russia), KP (North Korea)
  rule {
    name     = "GeoBlockingRule"
    priority = 3

    action {
      block {}
    }

    statement {
      geo_match_statement {
        country_codes = ["CN", "RU", "KP"]
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "GeoBlockingRule"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf-cloudfront"
    sampled_requests_enabled   = true
  }

  tags = {
    Name        = "${var.project_name}-waf"
    Environment = "production"
    Purpose     = "CloudFront protection"
  }
}

# CloudWatch Log Group for WAF
resource "aws_cloudwatch_log_group" "waf_log_group" {
  name              = "/aws/waf/${var.project_name}-cloudfront"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-waf-logs"
  }
}

# WAF Logging Configuration
resource "aws_wafv2_web_acl_logging_configuration" "cloudfront" {
  resource_arn            = aws_wafv2_web_acl.cloudfront.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf_log_group.arn]

  depends_on = [aws_cloudwatch_log_group.waf_log_group]
}

# CloudWatch Alarms for WAF
resource "aws_cloudwatch_metric_alarm" "waf_blocked_requests" {
  alarm_name          = "${var.project_name}-waf-blocked-requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = 300
  statistic           = "Sum"
  threshold           = 100
  alarm_description   = "Alert when WAF blocks >100 requests in 5 min"
  treat_missing_data  = "notBreaching"

  dimensions = {
    WebACL = aws_wafv2_web_acl.cloudfront.name
    Region = "GLOBAL"
  }
}

# Output
output "waf_arn" {
  description = "ARN of WAF Web ACL"
  value       = aws_wafv2_web_acl.cloudfront.arn
}

output "waf_id" {
  description = "ID of WAF Web ACL"
  value       = aws_wafv2_web_acl.cloudfront.id
}
