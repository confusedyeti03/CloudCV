# CloudCV - Portfolio & CV Website

Personal portfolio website for **Lluís Noval** at [lnoval.dev](https://lnoval.dev).

Fully serverless on AWS. Migrated from EC2 in July 2026 — see [PROGRESS.md](PROGRESS.md)
for the 8-phase migration history.

## Architecture

```
Cloudflare DNS (CNAME) → CloudFront (ACM TLS)
                             │
              ┌──────────────┴──────────────┐
              │                             │
     S3 website endpoint            API Gateway (/api/*)
     (HTML/CSS/JS/PDFs)                     │
                                      visit_counter (Lambda)
                                            │
                                    DynamoDB (visits)
```

- **Frontend**: Static HTML/CSS/JS on S3, served worldwide via CloudFront
- **API**: CloudFront proxies `/api/*` to API Gateway → Lambda (Python 3.11)
- **Database**: DynamoDB pay-per-request (visit counter)
- **DNS**: Cloudflare (DNS-only mode), TLS via ACM
- **Audit**: CloudTrail + CloudWatch dashboard and alarms
- **IaC**: Terraform (remote state in S3)

## Project Structure

```
CloudCV/
├── web/                    # Static frontend (deployed to S3)
│   ├── index.html          # Landing page
│   ├── cv/                 # CV page with embedded PDF viewer (CA/ES/EN)
│   ├── portfolio/          # AWS projects portfolio
│   ├── scripts/            # Shared JS (visit counter)
│   └── styles/             # Shared CSS
├── cv/
│   └── data/               # CV source data (YAML, single source of truth)
├── lambda/
│   └── visit_counter/      # POST /visits (Python 3.11)
├── terraform/              # Infrastructure as Code
│   ├── cloudfront.tf       # CDN, cache policies, /api/* proxy
│   ├── s3.tf               # Assets bucket (website endpoint)
│   ├── lambda.tf           # Functions + IAM
│   ├── dynamodb.tf         # Tables + TTL
│   ├── api-gateway.tf      # HTTP API + routes
│   ├── security.tf         # CloudTrail, KMS
│   ├── acm.tf              # TLS certificates
│   ├── dns.tf              # Cloudflare records
│   ├── dashboard.tf        # CloudWatch dashboard
│   └── budget.tf           # Monthly cost alert
└── scripts/
    ├── generate_pdfs.py        # Regenerate CV PDFs from YAML
    ├── build-lambda-zips.ps1   # Package Lambda functions
    └── upload-assets-to-s3.ps1 # Deploy web assets
```

## Prerequisites

- AWS CLI configured with credentials
- Terraform >= 1.0
- Python 3.11+ (PDF generation: `pip install reportlab pyyaml`)
- Cloudflare API token with DNS edit permissions

## Deployment

### 1. Infrastructure

```powershell
cd terraform
terraform init
terraform plan
terraform apply
```

Required variables in `terraform.tfvars`: `cloudflare_api_token`,
`cloudflare_zone_id`, `admin_email`.

### 2. Web assets

```powershell
aws s3 sync web/ s3://<assets-bucket>/ --region eu-west-1
aws cloudfront create-invalidation --distribution-id <id> --paths "/*"
```

Bucket and distribution ID come from `terraform output`.

### 3. CV PDFs (when the YAML data changes)

```powershell
python scripts/generate_pdfs.py   # writes to web/cv/
aws s3 cp web/cv/ s3://<assets-bucket>/cv/ --recursive --exclude "*" --include "*.pdf"
```

### 4. Lambda changes

```powershell
./scripts/build-lambda-zips.ps1
cd terraform
terraform apply
```

## Monitoring

- CloudWatch dashboard `example-cloudcv-serverless`: Lambda, API Gateway,
  DynamoDB and CloudFront metrics
- Alarms: Lambda errors/throttles, DynamoDB throttling
- Budget alert: email when monthly cost exceeds 80% of $6

## URLs

- **Landing**: https://lnoval.dev
- **CV**: https://lnoval.dev/cv/
- **Portfolio**: https://lnoval.dev/portfolio/
- **API (via CloudFront)**: https://lnoval.dev/api/visits

## Cost

~$1.50 USD/month (81% less than the previous EC2 setup at $8.05/month):

| Resource | ~Cost |
| --- | --- |
| KMS customer-managed key | $1.00/mo |
| S3 + CloudFront + Lambda + DynamoDB + API Gateway | ~$0.50/mo (mostly free tier) |
| Cloudflare DNS, ACM, CloudTrail (first trail) | Free |
