# CloudCV Migration Progress

## Current Status: FASE 8 Complete (EC2 Retired) — Only FASE 7 (Cost Analysis) Remaining

### Objective
Migrate CloudCV from EC2 ($8.05/month) to serverless architecture - **fully serverless as of 2026-07-05**

---

## Completed Phases

### FASE 1: Analysis & Strategy ✅
- Evaluated AWS 7R migration strategies
- Selected: Refactor (S3 + CloudFront + Lambda + DynamoDB)

### FASE 2: Static Assets (S3 + CloudFront) ✅
- S3 bucket with website configuration (directory index serving)
- CloudFront CDN with S3 website endpoint origin
- Custom domain (lnoval.dev) via ACM + Cloudflare DNS

### FASE 3: Serverless API (Lambda + DynamoDB + API Gateway) ✅ DEPLOYED
- 3 Lambda functions: cv_handler, visit_counter, projects_handler
- 3 DynamoDB tables: visits, cv_cache, projects_cache (pay-per-request)
- API Gateway HTTP API with CORS
- CloudWatch alarms for Lambda errors/throttles and DynamoDB

### FASE 4: PDF Generation ✅ (simplified)
- Skipped ECS Fargate — PDFs pre-generated locally with ReportLab
- Source data: `cv/data/cv_{ca,en,es}.yml`
- Generator: `scripts/generate_pdfs.py` → outputs to `cv/`
- PDFs served statically from S3 at `/cv/cv_*.pdf`

### FASE 5: Security ✅ DEPLOYED
- WAF Web ACL on CloudFront
- CloudTrail audit logging
- ACM certificate (TLS 1.2+, SNI)

### FASE 6: Assets Upload & Validation ✅
- All pages live with consistent pill-nav + hero-card styling:
  - `/` — Home (hero card, social links)
  - `/cv/` — Embedded PDF viewer + download buttons (CA/EN/ES)
  - `/portfolio/` — Projects, challenges, achievements
- Absolute paths for CSS/JS/assets (fixes subdirectory styling)

### FASE 8: EC2 Retirement ✅ (2026-07-05)
- Destroyed via Terraform (26 resources): EC2 instance, Elastic IP, VPC,
  subnet, IGW, route table, security group, EC2 IAM role/profile/policies,
  DLM snapshot policy, EC2 CloudWatch alarms, Nginx/system log groups
- Deleted 11 old EBS snapshots; kept newest (snap-06c068545b602bee8,
  2026-07-05) as temporary rollback — delete after confidence period
- Removed legacy code: `ansible/`, `cv-service/` (Flask/Docker service),
  `templates/`, obsolete scripts (run-local.sh, setup-wsl.sh,
  update-inventory.sh, test_cv_service.py)
- CV YAML data moved: `cv-service/data/` → `cv/data/`
- Verified zero downtime: all pages HTTP 200 before and after

---

### FASE 7: Cost Analysis & Monitoring ✅ (2026-07-05)
- CloudWatch dashboard `example-cloudcv-serverless` deployed
  (terraform/dashboard.tf): Lambda invocations/errors/duration,
  API Gateway requests/errors, DynamoDB capacity, CloudFront requests
- Budget alert active: $6/month, email at 80% (terraform/budget.tf)
- Cost Explorer unavailable (AWS Academy Learner Lab) — estimates used

**Estimated monthly cost (current architecture):**

| Item | USD/month |
|------|-----------|
| WAF (Web ACL $5 + 4 rules × $1) | ~9.00 |
| KMS customer-managed key | 1.00 |
| S3 + CloudFront + Lambda + DynamoDB + API GW (free tier) | ~0.50 |
| **Total with WAF** | **~10.50** |
| **Total without WAF** | **~1.50** |

**Pending decision:** WAF costs more than the old EC2 did. Removing it
(FASE7 doc recommendation for MVP) drops cost to ~$1.50/month (81%
savings vs EC2). Alternative protections that remain: CloudFront +
API Gateway throttling + budget alert.

---

## Architecture (current)

```
Cloudflare DNS (CNAME) → CloudFront (WAF, ACM TLS)
                             │
              ┌──────────────┴──────────────┐
              │                             │
     S3 website endpoint           API Gateway HTTP API
     (HTML/CSS/JS/PDFs)                     │
                              ┌─────────────┼─────────────┐
                         cv_handler   visit_counter  projects_handler
                              └──────── DynamoDB ─────────┘
                                 (visits, cv_cache, projects_cache)
```

## Key Files

| File | Purpose |
|------|---------|
| `terraform/cloudfront.tf` | CDN + cache policies + WAF association |
| `terraform/s3.tf` | Assets bucket + website config + public policy |
| `terraform/lambda.tf` | Lambda functions + IAM |
| `terraform/dynamodb.tf` | Tables + TTL + alarms |
| `terraform/api-gateway.tf` | HTTP API + routes + CORS |
| `terraform/security.tf` / `waf.tf` / `acm.tf` | FASE 5 security layer |
| `terraform/dns.tf` | Cloudflare records (CloudFront CNAME) |
| `terraform/budget.tf` | Monthly budget alert |
| `cv/data/cv_*.yml` | CV source data (single source of truth) |
| `scripts/generate_pdfs.py` | Regenerate PDFs from YAML |
| `scripts/upload-assets-to-s3.ps1` | Deploy web assets |

---

**Last Updated:** 2026-07-05
**Status:** Fully serverless. EC2 retired with zero downtime.
