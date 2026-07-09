# FASE 5: Security Configuration

## Objective

Add security layers: WAF, API authentication, HTTPS enforcement, audit logging.

## Components

### 1. CloudFront WAF
- Block common attacks (SQL injection, XSS)
- Rate limiting (IP-based)
- GeoIP blocking (optional)
- Cost: $5/month + $0.60/million requests

### 2. API Authentication
- API key validation (simple approach)
- JWT tokens (recommended)
- API Gateway authorizers
- Cost: $0.35/million authorizer calls

### 3. CloudTrail Logging
- Audit all AWS API calls
- S3 storage (logs)
- Cost: Free (first 100K events), $2 per 100K after

### 4. Request/Response Logging
- API Gateway request logging
- Lambda X-Ray tracing
- Cost: CloudWatch Logs ($0.50/GB)

## Deployment Steps

### Step 1: Create WAF Rules
```bash
terraform plan -target=aws_wafv2_web_acl.cloudfront -out=tfplan5a
terraform apply tfplan5a
```

### Step 2: Attach WAF to CloudFront
```bash
terraform plan -target=aws_cloudfront_distribution.static -out=tfplan5b
terraform apply tfplan5b
```

### Step 3: Configure API Key Validation
```bash
# Update Lambda environment variables with API key
terraform apply -var="api_key=your-secret-key"
```

### Step 4: Enable CloudTrail
```bash
terraform plan -target=aws_cloudtrail.main -out=tfplan5c
terraform apply tfplan5c
```

## WAF Rules

```
Rule 1: AWSManagedRulesCommonRuleSet
- Blocks common web vulnerabilities
- SQL injection, XSS, command injection
- Action: Block

Rule 2: AWSManagedRulesKnownBadInputsRuleSet
- Blocks known malicious input patterns
- Action: Block

Rule 3: RateLimitRule
- Max 2000 requests per 5 minutes per IP
- Action: Block

Rule 4: GeoBlockingRule (optional)
- Only allow traffic from EU/US/Asia
- Action: Block
```

## Terraform Files to Create

1. `waf.tf` (100 lines) - WAF rules and ACLs
2. `security.tf` (80 lines) - CloudTrail, KMS, S3 encryption
3. Update `api-gateway.tf` to add authorizer

## Cost Breakdown (FASE 5)

| Service | Cost |
|---------|------|
| WAF | $5.00/month |
| CloudTrail | $0.00 (free tier) |
| Authorizer calls | $0.35 (assuming low API usage) |
| **FASE 5 Total** | **$5.35/month** |

## Security Checklist

- [ ] WAF rules deployed
- [ ] API key validation working
- [ ] CloudTrail logging enabled
- [ ] S3 bucket encryption enabled
- [ ] VPC Flow Logs enabled
- [ ] AWS Config rules enabled
- [ ] Regular security assessments scheduled

## Next Steps

→ FASE 6: Assets upload and end-to-end validation

