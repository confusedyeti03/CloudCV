# AWS Lambda Functions for CloudCV
# Purpose: Serverless backend for CV API and visit tracking
#
# Function 1: cv-api-handler
# - Handles GET /cv/{language}
# - Returns CV data in JSON or PDF format
# - Replaces FastAPI endpoint
#
# Function 2: visit-counter
# - Increments visit count in DynamoDB
# - Triggered by API Gateway
# - Records analytics data

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

# Custom policy: DynamoDB read/write access (least privilege)
resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  name   = "${var.project_name}-lambda-dynamodb-policy"
  role   = aws_iam_role.lambda_execution_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.cv_cache.arn,
          aws_dynamodb_table.projects_cache.arn
        ]
      },
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

# Custom policy: S3 read access for assets
resource "aws_iam_role_policy" "lambda_s3_policy" {
  name   = "${var.project_name}-lambda-s3-policy"
  role   = aws_iam_role.lambda_execution_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.assets.arn}/*"
      }
    ]
  })
}

# Lambda Layer for Python dependencies
# Packages: requests, pyyaml, weasyprint, etc.
# Reduces function package size and improves cold start time
resource "aws_lambda_layer_version" "dependencies" {
  filename   = "lambda_layer.zip"  # Must be created manually (see Python requirements)
  layer_name = "${var.project_name}-python-dependencies"

  source_code_hash = filebase64sha256("lambda_layer.zip")

  compatible_runtimes = ["python3.11"]

  depends_on = [
    aws_iam_role.lambda_execution_role
  ]
}

# Lambda Function 1: CV API Handler
# Serves CV data in JSON or PDF format
resource "aws_lambda_function" "cv_handler" {
  filename      = "lambda_cv_handler.zip"
  function_name = "${var.project_name}-cv-handler"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 30  # 30 seconds max execution
  memory_size   = 512  # 512 MB RAM

  environment {
    variables = {
      DDB_CV_CACHE_TABLE = aws_dynamodb_table.cv_cache.name
      S3_BUCKET          = aws_s3_bucket.assets.id
      LOG_LEVEL          = "INFO"
    }
  }

  # Use Lambda layer for dependencies
  layers = [aws_lambda_layer_version.dependencies.arn]

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy.lambda_dynamodb_policy
  ]

  source_code_hash = filebase64sha256("lambda_cv_handler.zip")

  tags = {
    Name        = "${var.project_name}-cv-api"
    Environment = "production"
  }
}

# Lambda Function 2: Visit Counter
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

# Lambda Function 3: Projects List API
# Returns portfolio projects from cache
resource "aws_lambda_function" "projects_handler" {
  filename      = "lambda_projects_handler.zip"
  function_name = "${var.project_name}-projects-handler"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 10
  memory_size   = 256

  environment {
    variables = {
      DDB_PROJECTS_TABLE = aws_dynamodb_table.projects_cache.name
      LOG_LEVEL          = "INFO"
    }
  }

  layers = [aws_lambda_layer_version.dependencies.arn]

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy.lambda_dynamodb_policy
  ]

  source_code_hash = filebase64sha256("lambda_projects_handler.zip")

  tags = {
    Name        = "${var.project_name}-projects-api"
    Environment = "production"
  }
}

# CloudWatch Log Groups for Lambda
resource "aws_cloudwatch_log_group" "lambda_cv" {
  name              = "/aws/lambda/${aws_lambda_function.cv_handler.function_name}"
  retention_in_days = 7  # Keep logs for 7 days

  tags = {
    Name = "${var.project_name}-cv-logs"
  }
}

resource "aws_cloudwatch_log_group" "lambda_visits" {
  name              = "/aws/lambda/${aws_lambda_function.visit_counter.function_name}"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-visits-logs"
  }
}

resource "aws_cloudwatch_log_group" "lambda_projects" {
  name              = "/aws/lambda/${aws_lambda_function.projects_handler.function_name}"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-projects-logs"
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
    FunctionName = aws_lambda_function.cv_handler.function_name
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
    FunctionName = aws_lambda_function.cv_handler.function_name
  }
}

# Lambda permission for API Gateway invocation
resource "aws_lambda_permission" "cv_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cv_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*/*"
}

resource "aws_lambda_permission" "visit_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visit_counter.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*/*"
}

resource "aws_lambda_permission" "projects_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.projects_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*/*"
}

# Outputs for use in API Gateway
output "lambda_cv_handler_arn" {
  description = "ARN of CV handler Lambda function"
  value       = aws_lambda_function.cv_handler.arn
}

output "lambda_cv_handler_invoke_arn" {
  description = "Invoke ARN for API Gateway"
  value       = aws_lambda_function.cv_handler.invoke_arn
}

output "lambda_visit_counter_invoke_arn" {
  description = "Invoke ARN for visit counter Lambda"
  value       = aws_lambda_function.visit_counter.invoke_arn
}

output "lambda_projects_handler_invoke_arn" {
  description = "Invoke ARN for projects handler Lambda"
  value       = aws_lambda_function.projects_handler.invoke_arn
}
