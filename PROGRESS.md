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
- CloudTrail audit logging
- ACM certificate (TLS 1.2+, SNI)
- WAF was deployed here but removed in FASE 7 (cost ~$9/month)

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

**WAF removed (2026-07-05):** it cost ~$9/month (Web ACL $5 + 4 rules
× $1) — more than the old EC2. Disassociated from CloudFront (in-place
update, zero downtime), then Web ACL + log group + alarm destroyed.
Remaining protections: HTTPS-only, API Gateway throttling, budget alert.

**Estimated monthly cost (final architecture):**

| Item | USD/month |
|------|-----------|
| KMS customer-managed key | 1.00 |
| S3 + CloudFront + Lambda + DynamoDB + API GW (free tier) | ~0.50 |
| **Total** | **~1.50** (81% savings vs EC2 $8.05) |

---

## Post-migration fixes (2026-07-05)

- **Visit counter connected and fixed** — it was broken in three ways:
  1. No CloudFront route for `/api/*`: added API Gateway origin +
     `/api/*` behavior (POST allowed, caching disabled) with a
     CloudFront function stripping the `/api` prefix (`/api/visits` →
     `/prod/visits`)
  2. Lambda keyed items by current timestamp, so every visit created a
     new item with count 1: now increments an aggregate item per page
     (sort key 0, no TTL) atomically
  3. `visits.js` read `data.count` but Lambda returns `visit_count`;
     also now sends `page_id` derived from the path and tolerates pages
     without the counter element
  - Verified end-to-end: `POST https://lnoval.dev/api/visits` returns
    JSON and increments (1 → 2)
- **Orphan cleanup**: removed unused CloudFront OAI and the
  never-associated `directory_index` function
- **README.md rewritten** for the serverless architecture (was EC2-era)
- **Dead config removed (Terraform audit)**:
  - S3 access logging that never delivered (required an ACL that was
    commented out) and would have exposed logs publicly if it had
  - CloudTrail→CloudWatch log group, IAM role and policy the trail
    never referenced, plus the `unauthorized_api_calls` alarm watching
    a metric nothing publishes
- **Soft-404 fixed**: new styled `web/404.html`, S3 website
  `error_document` now returns it with a real 404 status; removed the
  CloudFront 403→200 index.html rewrite that masked all errors as the
  homepage
- **Unused backend retired**: `cv_handler` and `projects_handler`
  Lambdas (frontend serves PDFs and projects.json statically), their
  API routes/integrations, `cv_cache` and `projects_cache` tables,
  the dependencies layer and the S3 IAM policy; alarms and dashboard
  re-pointed to `visit_counter`; fixed the visits throttle alarm
  (watched ConsumedWriteCapacityUnits — fired on every write — now
  WriteThrottleEvents)
- **Repo cleanup**: fixed corrupted .gitignore tail, untracked Lambda
  zips (regenerated by `build-lambda-zips.ps1`), single copy of CV PDFs
  in `web/cv/` (`generate_pdfs.py` now writes there), removed
  `lambda/api_authorizer` (never deployed), empty dirs and the
  duplicate achievement card in the portfolio (also unified absolute
  asset paths)

## Final review fixes (2026-07-09)

- **Terraform state migrated to S3**: bootstrap applied (bucket
  `example-cloudcv-tfstate-002645520899`, versioned + encrypted),
  `backend.tf` created, `terraform init -migrate-state` done — state
  no longer lives only on one disk
- **Stale content fixed**: CloudCV card in projects.json now describes
  the serverless architecture (~$1.5/mo); home deploy badge no longer
  mentions Ansible; generate_pdfs.py help no longer suggests a removed
  API endpoint
- **Coherent naming**: `project_name` default is `example-cloudcv`
  everywhere (variables.tf, Lambda fallback); dead EC2 vars removed
  from terraform.tfvars
- **Portfolio now tracks visits** (loads visits.js) and shows the
  Credly badge "AWS Microcredential: Serverless Demonstrated" linking
  to its verification page
- **Misc**: Let's Encrypt CAA record removed from dns.tf, budget
  lowered to $3/month, upload script uploads HTML with no-cache,
  FASE*.md moved to docs/ as historical documentation

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
