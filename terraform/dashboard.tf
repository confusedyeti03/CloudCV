# FASE 7: CloudWatch Dashboard - Serverless monitoring
# Single pane of glass for Lambda, API Gateway, DynamoDB and CloudFront.
# Cost: first 3 dashboards are free (this is the only one).

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-serverless"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Lambda - Invocations"
          region = var.aws_region
          stat   = "Sum"
          period = 3600
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.cv_handler.function_name],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.visit_counter.function_name],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.projects_handler.function_name]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Lambda - Errors & Throttles"
          region = var.aws_region
          stat   = "Sum"
          period = 3600
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.cv_handler.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.visit_counter.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.projects_handler.function_name],
            ["AWS/Lambda", "Throttles", "FunctionName", aws_lambda_function.cv_handler.function_name]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Lambda - Duration (avg ms)"
          region = var.aws_region
          stat   = "Average"
          period = 3600
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.cv_handler.function_name],
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.visit_counter.function_name],
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.projects_handler.function_name]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "API Gateway - Requests & Errors"
          region = var.aws_region
          stat   = "Sum"
          period = 3600
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiId", aws_apigatewayv2_api.cv_api.id],
            ["AWS/ApiGateway", "4xx", "ApiId", aws_apigatewayv2_api.cv_api.id],
            ["AWS/ApiGateway", "5xx", "ApiId", aws_apigatewayv2_api.cv_api.id]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "DynamoDB - Consumed Capacity"
          region = var.aws_region
          stat   = "Sum"
          period = 3600
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", aws_dynamodb_table.visits.name],
            ["AWS/DynamoDB", "ConsumedWriteCapacityUnits", "TableName", aws_dynamodb_table.visits.name],
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", aws_dynamodb_table.cv_cache.name],
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", aws_dynamodb_table.projects_cache.name]
          ]
        }
      },
      {
        # CloudFront publishes metrics only in us-east-1 (global service)
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "CloudFront - Requests & Error Rates"
          region = "us-east-1"
          period = 3600
          metrics = [
            ["AWS/CloudFront", "Requests", "DistributionId", aws_cloudfront_distribution.static.id, "Region", "Global", { stat = "Sum" }],
            ["AWS/CloudFront", "4xxErrorRate", "DistributionId", aws_cloudfront_distribution.static.id, "Region", "Global", { stat = "Average", yAxis = "right" }],
            ["AWS/CloudFront", "5xxErrorRate", "DistributionId", aws_cloudfront_distribution.static.id, "Region", "Global", { stat = "Average", yAxis = "right" }]
          ]
        }
      }
    ]
  })
}

output "dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}
