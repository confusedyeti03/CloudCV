# =============================================================================
# Variables for State Bootstrap
# =============================================================================

variable "aws_region" {
  description = "AWS region for the state bucket"
  type        = string
  default     = "eu-west-1"
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
  default     = "lnoval-terraform-state"
}
