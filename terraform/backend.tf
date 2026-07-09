# Remote state in S3 (bucket created by state-bootstrap/)
# Backend blocks cannot use variables - values are set manually.
terraform {
  backend "s3" {
    bucket       = "example-cloudcv-tfstate-002645520899"
    key          = "cloudcv/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
    encrypt      = true
  }
}
