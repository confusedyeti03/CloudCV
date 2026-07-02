# AWS API Gateway HTTP API
# FASE 5: Added security with WAF and optional API key authentication

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-api-logs"
  }
}

# HTTP API
resource "aws_apigatewayv2_api" "cv_api" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
  description   = "CV and portfolio API"

  cors_configuration {
    allow_credentials = false
    allow_headers     = ["*"]
    allow_methods     = ["GET", "POST", "OPTIONS"]
    allow_origins     = ["https://${var.domain}", "https://www.${var.domain}"]
    max_age           = 86400
  }

  tags = {
    Name = "${var.project_name}-api"
  }
}

# API Stage
resource "aws_apigatewayv2_stage" "api_stage" {
  api_id      = aws_apigatewayv2_api.cv_api.id
  name        = "prod"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId = "$context.requestId"
      status    = "$context.status"
      method    = "$context.httpMethod"
    })
  }

  depends_on = [aws_cloudwatch_log_group.api_gateway]
}

# Route: GET /cv/{language}
resource "aws_apigatewayv2_route" "cv_get" {
  api_id             = aws_apigatewayv2_api.cv_api.id
  route_key          = "GET /cv/{language}"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.cv_handler.id}"
}

# Route: GET /cv/{language}/pdf
resource "aws_apigatewayv2_route" "cv_pdf_get" {
  api_id             = aws_apigatewayv2_api.cv_api.id
  route_key          = "GET /cv/{language}/pdf"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.cv_handler.id}"
}

# Integration: Lambda for /cv/{language}
resource "aws_apigatewayv2_integration" "cv_handler" {
  api_id             = aws_apigatewayv2_api.cv_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.cv_handler.invoke_arn
  payload_format_version = "2.0"
}

# Route: GET /projects
resource "aws_apigatewayv2_route" "projects_list" {
  api_id             = aws_apigatewayv2_api.cv_api.id
  route_key          = "GET /projects"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.projects_handler.id}"
}

# Integration: Lambda for /projects
resource "aws_apigatewayv2_integration" "projects_handler" {
  api_id             = aws_apigatewayv2_api.cv_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.projects_handler.invoke_arn
  payload_format_version = "2.0"
}

# Route: POST /visits (Protected - requires API key)
# FASE 5: Add API key validation via custom header check
resource "aws_apigatewayv2_route" "visits_post" {
  api_id             = aws_apigatewayv2_api.cv_api.id
  route_key          = "POST /visits"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.visit_counter.id}"

  # Note: API key validation is handled by visit_counter Lambda
  # Expects X-API-Key header or Authorization: Bearer <key>
}

# Integration: Lambda for /visits
resource "aws_apigatewayv2_integration" "visit_counter" {
  api_id             = aws_apigatewayv2_api.cv_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.visit_counter.invoke_arn
  payload_format_version = "2.0"
}

# Outputs
output "api_endpoint" {
  description = "API Gateway endpoint"
  value       = aws_apigatewayv2_api.cv_api.api_endpoint
}

output "api_invoke_url" {
  description = "Full API invoke URL"
  value       = "${aws_apigatewayv2_stage.api_stage.invoke_url}"
}
