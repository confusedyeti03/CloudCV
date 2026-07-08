# AWS Lambda Functions for CloudCV
# Purpose: Serverless backend for visit tracking
#
# visit-counter: increments the per-page visit count in DynamoDB,
# invoked by API Gateway (POST /visits, proxied by CloudFront at /api/visits)

# IAM Role for Lambda functions
# Principle: Least privilege - only permissions needed
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.project_name}-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Attach basic execution policy (CloudWatch Logs)
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Custom policy: DynamoDB write access to the visits table (least privilege)
resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  name   = "${var.project_name}-lambda-dynamodb-policy"
  role   = aws_iam_role.lambda_execution_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.visits.arn
      }
    ]
  })
}

# Lambda Function: Visit Counter
# Increments visit count in DynamoDB
resource "aws_lambda_function" "visit_counter" {
  filename      = "lambda_visit_counter.zip"
  function_name = "${var.project_name}-visit-counter"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 5  # 5 seconds (quick operation)
  memory_size   = 128  # 128 MB RAM (minimal)

  environment {
    variables = {
      DDB_VISITS_TABLE = aws_dynamodb_table.visits.name
      LOG_LEVEL        = "INFO"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy.lambda_dynamodb_policy
  ]

  source_code_hash = filebase64sha256("lambda_visit_counter.zip")

  tags = {
    Name        = "${var.project_name}-visit-counter"
    Environment = "production"
  }
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_visits" {
  name              = "/aws/lambda/${aws_lambda_function.visit_counter.function_name}"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-visits-logs"
  }
}

# CloudWatch Alarms for Lambda monitoring
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_name}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 5  # Alert if >5 errors per minute
  alarm_description   = "Alert when Lambda functions have errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.visit_counter.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${var.project_name}-lambda-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0  # Alert on any throttle
  alarm_description   = "Alert when Lambda functions are throttled"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.visit_counter.function_name
  }
}

# Lambda permission for API Gateway invocation
resource "aws_lambda_permission" "visit_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visit_counter.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*/*"
}

output "lambda_visit_counter_invoke_arn" {
  description = "Invoke ARN for visit counter Lambda"
  value       = aws_lambda_function.visit_counter.invoke_arn
}
