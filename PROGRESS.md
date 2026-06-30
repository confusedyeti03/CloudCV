# CloudCV Migration Progress

## Current Status: FASE 3 (Ready for Deployment)

### Objective
Migrate CloudCV from EC2 ($8.05/month) to serverless architecture ($1.67/month) - **79% cost reduction**

---

## Completed Phases

### FASE 1: Analysis & Strategy
- Evaluated AWS 7R migration strategies
- Selected: Refactor (S3 + CloudFront + Lambda + DynamoDB)
- Defined Well-Architected Framework principles

### FASE 2: Static Assets (S3 + CloudFront)
- S3 bucket for HTML/CSS/JS/assets
- CloudFront CDN distribution
- Cost: $0.52/month
- Status: ✅ Complete

### FASE 3: Serverless API (Lambda + DynamoDB + API Gateway)
- **3 Lambda Functions (Python 3.11):**
  - `cv_handler`: GET /cv/{language} + PDF generation (30s timeout, 512MB)
  - `visit_counter`: POST /visits counter tracking (5s timeout, 128MB)
  - `projects_handler`: GET /projects filtering (10s timeout, 256MB)

- **DynamoDB Tables (Pay-per-Request):**
  - `visits`: Visit tracking with 90-day TTL
  - `cv_cache`: CV HTML cache with variable TTL
  - `projects_cache`: Projects JSON cache

- **API Gateway HTTP API:**
  - 5 routes: GET /cv/{language}, GET /projects, POST /visits, OPTIONS
  - CORS enabled for lnoval.dev domains
  - CloudWatch access logging

- **Monitoring:**
  - CloudWatch alarms for Lambda errors & throttles
  - DynamoDB throttling alerts
  - 7-day log retention

- **Code Status:**
  - `lambda/cv_handler/index.py` - ✅ Complete
  - `lambda/visit_counter/index.py` - ✅ Complete
  - `lambda/projects_handler/index.py` - ✅ Complete
  - `lambda_layer/` with requests - ✅ Complete
  - All .zip packages created - ✅ Complete
  - Terraform .tf files - ✅ Complete

- **Cost:** $1.15/month
- **Total (FASE 2+3):** $1.67/month
- **Status:** ⏳ Ready to deploy (AWS credentials required)

---

## Pending Phases (Documented)

### FASE 4: Complex Backend (ECS Fargate) - *Optional*
- PDF generation with weasyprint
- Cost: $0.25/month (Spot instances) or skip for MVP
- Docs: [FASE4_CONTAINERIZATION.md](terraform/FASE4_CONTAINERIZATION.md)
- Recommendation: Skip for MVP (pre-generate PDFs instead)

### FASE 5: Security (WAF + Authentication) - *Optional*
- CloudFront WAF rules
- API key/JWT authentication
- CloudTrail audit logging
- Cost: $5.00/month
- Docs: [FASE5_SECURITY.md](terraform/FASE5_SECURITY.md)
- Recommendation: Skip for MVP (add later if needed)

### FASE 6: Assets & Validation
- S3 asset upload procedures
- API endpoint testing
- End-to-end validation checklist
- Docs: [FASE6_DEPLOYMENT.md](terraform/FASE6_DEPLOYMENT.md)

### FASE 7: Cost Analysis & Monitoring
- CloudWatch dashboards
- Cost alerts and optimization
- Monthly cost tracking
- Docs: [FASE7_COST_ANALYSIS.md](terraform/FASE7_COST_ANALYSIS.md)

### FASE 8: EC2 Retirement
- Terminate EC2 instance
- Release Elastic IP
- Archive Ansible playbooks
- Update DNS records
- Cost: 76% savings achieved
- Docs: [FASE8_RETIREMENT.md](terraform/FASE8_RETIREMENT.md)

---

## Next Steps

1. **Configure AWS Credentials:**
   ```bash
   aws configure
   # Enter: Access Key ID, Secret Access Key, region (eu-west-1), format (json)
   ```

2. **Deploy FASE 3:**
   ```bash
   cd terraform
   terraform plan -out=tfplan3
   terraform apply tfplan3
   ```

3. **Validate Deployment:**
   ```bash
   # Get API URL
   API_URL=$(terraform output -raw api_invoke_url)
   
   # Test endpoints
   curl $API_URL/health
   curl $API_URL/cv/en
   curl $API_URL/projects
   ```

4. **Proceed to FASE 4-8:**
   - FASE 4: Evaluate PDF generation needs (Fargate vs pre-generation)
   - FASE 5: Decide on WAF/security layer (required for production)
   - FASE 6: Upload assets and validate
   - FASE 7: Monitor costs and optimize
   - FASE 8: Retire EC2 instance

---

## Key Files

| File | Purpose |
|------|---------|
| `terraform/lambda.tf` | Lambda functions + IAM + CloudWatch |
| `terraform/dynamodb.tf` | DynamoDB tables + TTL + alarms |
| `terraform/api-gateway.tf` | HTTP API + routes + CORS |
| `terraform/s3.tf` | S3 bucket + CloudFront integration |
| `terraform/cloudfront.tf` | CloudFront distribution + caching |
| `lambda/cv_handler/index.py` | CV API handler |
| `lambda/visit_counter/index.py` | Visit tracking handler |
| `lambda/projects_handler/index.py` | Projects API handler |
| `terraform/FASE4_CONTAINERIZATION.md` | ECS Fargate implementation |
| `terraform/FASE5_SECURITY.md` | WAF + authentication setup |
| `terraform/FASE6_DEPLOYMENT.md` | Asset upload + validation |
| `terraform/FASE7_COST_ANALYSIS.md` | Monitoring + optimization |
| `terraform/FASE8_RETIREMENT.md` | EC2 decommissioning |

---

## Architecture

```
┌─────────────────────────────────────────┐
│      CloudFront (FASE 2)                │
│  - Static assets caching                │
│  - $0.52/month                          │
└──────────────┬──────────────────────────┘
               │
       ┌───────┴────────┐
       │                │
   ┌───▼──────┐    ┌───▼──────┐
   │    S3    │    │   API    │
   │ Assets   │    │ Gateway  │
   └──────────┘    └───┬──────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
   ┌────▼────┐  ┌─────▼─────┐  ┌────▼────┐
   │ Lambda  │  │ DynamoDB  │  │ Lambda  │
   │  cv_    │  │ Tables    │  │ visit_  │
   │ handler │  │ (3 tables)│  │ counter │
   └─────────┘  └───────────┘  └─────────┘
   (PDF/HTML)    (Cache/Visits) (Analytics)
   
   $1.15/month                $0.52/month
```

---

## Commit Strategy

- **Commit 1 (FASE 3):** Lambda, DynamoDB, API Gateway infrastructure
- **Commit 2 (Documentation):** FASE 4-8 implementation guides
- **Commit 3 (Post-FASE3):** Terraform apply results + validation
- **Commit 4 (FASE 4+):** Additional phases implementation

---

## Environment

- **OS:** Windows 11 Pro
- **AWS Region:** eu-west-1 (Ireland)
- **Python:** 3.11 (Lambda)
- **Terraform:** >= 1.0
- **Cost Target:** $1.67/month

---

**Last Updated:** 2026-06-30
**Status:** FASE 3 ready for AWS deployment
