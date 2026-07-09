# FASE 4: Containerization and ECS Fargate Spot

## Objective

FASE 4 deploys complex backend logic (CV PDF generation, asset processing) to ECS Fargate Spot. This provides:
- Fallback execution for Lambda timeouts
- Ability to run long-running tasks (PDF generation > 30 seconds)
- Cost optimization via Spot instances (70% discount)
- Proper weasyprint/pyyaml support (full Python environment)

## Architecture Change

```
Before FASE 4:
API Gateway → Lambda (30s timeout) → DynamoDB/S3
                ↓
            (timeout error for PDF generation)

After FASE 4:
API Gateway → Lambda (5s timeout, fast-fail) → DynamoDB/S3
                ↓
            ECS Fargate Spot (no timeout) → PDF generation → S3
```

## Why FASE 4 is Necessary

1. **Lambda timeout issue**: PDF generation with WeasyPrint takes 30-60+ seconds
2. **Python dependencies**: weasyprint, PIL require system libraries (not available in Lambda zip)
3. **Cost optimization**: Fargate Spot costs ~$0.02/hour vs Lambda $0.20/invocation
4. **Scalability**: Fargate can handle concurrent PDF generation jobs

## What Gets Deployed

### 1. Docker Image (ECR)
- Base: `python:3.11-slim`
- Packages: weasyprint, pyyaml, requests, Pillow
- Entrypoint: FastAPI app running on port 8000
- Size: ~500MB

### 2. ECS Cluster
- Fargate launch type (serverless containers)
- Task role with S3 + DynamoDB access
- Task definition with:
  - CPU: 512 (0.5 vCPU)
  - Memory: 1024 MB
  - Container timeout: 60 seconds
  - Spot capacity provider (70% cost savings)

### 3. Networking
- Security group allowing port 8000 from API Gateway
- VPC endpoints for S3/DynamoDB (cost optimization)
- Application Load Balancer (optional, for auto-scaling)

## Terraform Files to Create

1. `ecs.tf` (180 lines)
   - ECS cluster
   - Task definition (CPU/memory/logging)
   - Service with Fargate Spot
   - Auto-scaling based on CPU
   - CloudWatch alarms

2. `ecr.tf` (50 lines)
   - ECR repository for Docker image
   - Image retention policy
   - Lifecycle rules

3. `alb.tf` (120 lines)
   - Application Load Balancer
   - Target groups
   - Listener rules
   - Health checks

## Deployment Steps

### Step 1: Build Docker Image
```bash
# Create Dockerfile in project root
docker build -t lnoval-cv-backend:latest .
```

### Step 2: Push to ECR
```bash
# Create ECR repository
aws ecr create-repository --repository-name lnoval-cv-backend

# Login to ECR
aws ecr get-login-password | docker login --username AWS --password-stdin <account-id>.dkr.ecr.eu-west-1.amazonaws.com

# Tag and push
docker tag lnoval-cv-backend:latest <account-id>.dkr.ecr.eu-west-1.amazonaws.com/lnoval-cv-backend:latest
docker push <account-id>.dkr.ecr.eu-west-1.amazonaws.com/lnoval-cv-backend:latest
```

### Step 3: Deploy ECS Cluster
```bash
cd terraform
terraform plan -target=aws_ecs_cluster.backend -out=tfplan4
terraform apply tfplan4
```

### Step 4: Test Fargate Service
```bash
# Get service endpoint
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test PDF generation
curl -X POST "http://$ALB_DNS/api/pdf-generator" \
  -H "Content-Type: application/json" \
  -d '{"language": "en"}'

# Check logs
aws logs tail /ecs/lnoval-cv-backend --follow
```

## Cost Breakdown (FASE 4)

| Service | Volume | Price | Monthly |
|---------|--------|-------|---------|
| ECR Storage | 500MB | $0.10 per GB | $0.05 |
| ECS Fargate Spot | 10 hours/month | $0.02/hour | $0.20 |
| ALB | 1 ALB | $16.20/month | $16.20 |
| **FASE 4 Total** | | | **$16.45** |

**Combined (FASE 2+3+4)**: $0.52 + $1.10 + $16.45 = **$18.07/month**

⚠️ **Note**: ALB cost ($16/month) dominates. Consider removing ALB if not needed, use direct API Gateway → ECS service discovery instead.

## Optimization Options

### Option A: Remove ALB (cheaper)
- Use API Gateway direct integration to ECS service
- AWS PrivateLink endpoint
- Cost: $0.25/month instead of $16.20
- Trade-off: No traditional load balancing

### Option B: Use Lambda for fast operations
- Keep Lambda for cv/{language} (caching)
- Use ECS only for PDF generation (async)
- Cost: Hybrid approach, best of both

### Option C: Use S3 pre-generated PDFs
- Pre-generate PDFs during CI/CD
- Serve from S3 via CloudFront
- Cost: Minimal ($0.52), no ECS needed

## Recommended Approach (MVP)

For CloudCV MVP, use **Option C** (pre-generated PDFs):
1. Generate PDFs locally during CI/CD
2. Upload to S3
3. Serve via CloudFront + Lambda redirect
4. Cost: $0.52/month (no ECS needed)
5. Trade-off: PDFs can't be dynamic (language only)

If dynamic PDF generation needed, defer to FASE 5.

## Success Criteria

- [ ] Docker image builds successfully
- [ ] Image pushed to ECR
- [ ] ECS cluster created
- [ ] Task definition registered
- [ ] Service running on Fargate Spot
- [ ] CloudWatch logs show successful execution
- [ ] PDF generation completes in < 60 seconds
- [ ] Cost is <= $20/month (including ALB)

## Rollback

```bash
terraform destroy -target=aws_ecs_service.backend -auto-approve
terraform destroy -target=aws_ecs_task_definition.backend -auto-approve
```

## Next Steps

→ FASE 5: Security configuration (WAF, API auth)

