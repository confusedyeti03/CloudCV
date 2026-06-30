# FASE 7: Cost Analysis and Optimization

## Objective

Analyze actual costs and identify optimization opportunities.

## Cost Comparison

### Original (EC2)
```
EC2 t4g.nano        : $3.50/month
Elastic IP          : $3.60/month (only when stopped)
EBS 8GB             : $0.65/month
CloudWatch Logs     : $0.30/month (Nginx logs)
TOTAL               : $8.05/month (+ optional costs)
```

### FASE 2 (S3 + CloudFront)
```
S3 Storage          : $0.10/month  (100 GB at $0.023/GB)
S3 Requests         : $0.01/month  (GET, PUT, LIST)
CloudFront Transfer : $0.40/month  (1 GB at $0.085/GB, cached)
TOTAL               : $0.52/month
SAVINGS vs EC2      : 94% ($7.53/month saved)
```

### FASE 3 (Lambda + DynamoDB)
```
Lambda invocations  : $0.20/month (1M invocations in free tier)
DynamoDB reads      : $0.10/month (~1M reads, pay-per-request)
DynamoDB writes     : $0.15/month (~1M writes, pay-per-request)
DynamoDB storage    : $0.05/month (100 MB)
API Gateway         : $0.35/month
CloudWatch Logs     : $0.30/month
TOTAL               : $1.15/month
CUMULATIVE (2+3)    : $1.67/month
SAVINGS vs EC2      : 79% ($6.38/month saved)
```

### FASE 4 (ECS Fargate)
```
ECS Fargate Spot    : $0.20/month (10 hours, assuming low PDF generation)
ECR Storage         : $0.05/month
(NO ALB - use API Gateway direct)
TOTAL               : $0.25/month
CUMULATIVE (2+3+4)  : $1.92/month
SAVINGS vs EC2      : 76% ($6.13/month saved)
```

### FASE 5 (WAF + Security)
```
WAF                 : $5.00/month (minimum)
CloudTrail          : $0.00/month (free tier)
TOTAL               : $5.00/month
CUMULATIVE (2+3+4+5): $6.92/month
SAVINGS vs EC2      : 14% ($1.13/month saved)
```

## Optimization Opportunities

### High Priority (Impact: $5+)
1. **Remove WAF** (if not required)
   - FASE 5 cost: $5.00 → $0
   - Trade-off: Less DDoS protection
   - Alternative: CloudFront geographic restrictions

2. **Compress assets more**
   - Current: Gzip + Brotli on CloudFront
   - Further: Precompress SVG/JSON in S3
   - Savings: $0.10/month

### Medium Priority (Impact: $0.1-1)
1. **Lambda memory optimization**
   - Current: 512 MB for cv_handler, 128 for visits
   - Try: 256 MB for cv_handler (if PDF generation still works)
   - Savings: $0.05/month

2. **DynamoDB TTL tuning**
   - Current: 90 days for visits
   - Try: 30 days (for less storage)
   - Savings: $0.01/month

3. **CloudWatch Logs retention**
   - Current: 7 days
   - Try: 3 days (for older logs)
   - Savings: $0.10/month

### Low Priority (Impact: < $0.1)
1. Reserved capacity for DynamoDB
2. CloudFront partial caching for HTML
3. Lambda provisioned concurrency

## Recommended Configuration (MVP)

```
FASE 2: S3 + CloudFront        : $0.52/month ✅
FASE 3: Lambda + DynamoDB      : $1.15/month ✅
FASE 4: ECS (skip for MVP)     : $0/month   ⏭️
FASE 5: WAF (skip for MVP)     : $0/month   ⏭️
OPTIMIZATION: Remove high-cost items

TARGET TOTAL                    : $1.67/month
SAVINGS vs EC2                  : 79%
```

## Monitoring Dashboard

Create CloudWatch dashboard with:
- EC2 costs (ATUAL vs FASE 2-3)
- Lambda invocations & duration
- DynamoDB read/write units
- CloudFront cache hit rate
- API response times

## Cost Alerts

Set up CloudWatch alarms:
- Monthly bill > $3 (alert)
- DynamoDB writes > 10M/month (check for runaway queries)
- Lambda duration > 30s (80+ percentile)

## Validation Checklist

- [ ] AWS Cost Explorer shows $1.67/month
- [ ] CloudWatch dashboard created
- [ ] Billing alerts configured
- [ ] Optimization recommendations reviewed

## Next Steps

→ FASE 8: Retire old resources

