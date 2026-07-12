# AWS Account Information
data "aws_caller_identity" "current" {}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "example-cloudcv"
}

variable "domain" {
  description = "Domain name"
  type        = string
  default     = "lnoval.dev"
}

variable "admin_email" {
  description = "Administrative email for DMARC reporting"
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for lnoval.dev"
  type        = string
}

variable "monthly_budget" {
  description = "Monthly budget alert threshold in USD (alert at 80%)"
  type        = number
  default     = 3
}
