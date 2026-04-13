# Terraform State Bootstrap

This directory contains the Terraform configuration to create the S3 bucket
used for storing the main Terraform state.

## Usage

1. Configure AWS credentials (AWS Academy credentials from Learner Lab)
2. Run:
   ```bash
   cd terraform/state-bootstrap
   terraform init
   terraform apply
   ```
3. After the bucket is created, you can run the main terraform configuration

## Note

This only needs to be run ONCE to create the state bucket.
