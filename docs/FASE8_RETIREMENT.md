# FASE 8: Retire Old Resources

## Objective

Remove EC2 instance, Elastic IP, and associated resources. Migrate DNS fully to serverless.

## Pre-Retirement Checklist

Before deleting anything, verify:
- [ ] All data migrated to DynamoDB/S3
- [ ] CloudFront is caching properly
- [ ] API endpoints responding
- [ ] Visit tracking working
- [ ] Browser testing successful
- [ ] DNS pointing to CloudFront (not EC2)
- [ ] No applications dependent on EC2

## Resources to Delete

### 1. EC2 Instance
```bash
# Terminate instance
aws ec2 terminate-instances --instance-ids i-xxxx --region eu-west-1

# Verify termination
aws ec2 describe-instances --instance-ids i-xxxx --query 'Reservations[0].Instances[0].State.Name'
# Should be: "terminated"
```

### 2. Elastic IP
```bash
# Release Elastic IP
aws ec2 release-address --allocation-id eipalloc-xxxx --region eu-west-1
```

### 3. Security Groups
```bash
# Delete security group (if no other resources use it)
aws ec2 delete-security-group --group-id sg-xxxx --region eu-west-1
```

### 4. VPC (optional, if only used for this project)
```bash
# Delete VPC (will delete subnets, route tables automatically)
aws ec2 delete-vpc --vpc-id vpc-xxxx --region eu-west-1
```

### 5. Ansible Playbooks
```bash
# Archive for reference, then delete
mv ansible/ ansible.backup/
git add ansible.backup/
git commit -m "FASE 8: Archive Ansible playbooks (migrated to Terraform)"
```

### 6. IAM Roles (EC2-related)
```bash
# List roles
aws iam list-roles | grep ec2

# Delete role
aws iam delete-role --role-name lnoval-cv-ec2-role
```

## Terraform Cleanup

### Option A: Selective Destruction
```bash
# Remove only EC2-related resources from Terraform
terraform state rm aws_instance.web
terraform state rm aws_eip.web
terraform state rm aws_security_group.web

# Verify state
terraform state list | grep instance
# Should return nothing
```

### Option B: Full Destruction & Rebuild
```bash
# Backup current state
cp terraform.tfstate terraform.tfstate.backup

# Destroy only old EC2 resources
terraform plan -destroy -target=aws_instance.web -out=tfplan_destroy
terraform apply tfplan_destroy

# Remove old EC2 Terraform files
rm terraform/ec2.tf
```

## DNS Migration

### Before (A record to Elastic IP)
```
lnoval.dev  A  3.123.45.67 (Elastic IP)
```

### After (CNAME to CloudFront)
```
lnoval.dev  CNAME  d123abc.cloudfront.net
```

**Status**: Should already be done in FASE 2. Verify:
```bash
nslookup lnoval.dev
# Should return CloudFront domain, not EC2 IP
```

## Monitoring After Retirement

### Check CloudWatch for EC2 metrics (should be gone)
```bash
aws cloudwatch list-metrics --namespace AWS/EC2 --region eu-west-1
# Should return empty
```

### Verify application is working
```bash
# Test from different locations
curl -I https://lnoval.dev
curl -I https://www.lnoval.dev
curl -I $(terraform output -raw api_invoke_url)/health

# All should return 200
```

### Monitor AWS bill
```bash
# Next AWS bill should show no EC2 charges
# Expected: $1.67/month vs $8.05/month
```

## Cost Verification

| Service | BEFORE | AFTER | SAVINGS |
|---------|--------|-------|---------|
| EC2 | $3.50 | $0.00 | $3.50 |
| Elastic IP | $3.60 | $0.00 | $3.60 |
| EBS | $0.65 | $0.00 | $0.65 |
| CloudWatch | $0.30 | $0.30 | $0.00 |
| CloudFront | $0.00 | $0.52 | -$0.52 |
| Lambda | $0.00 | $1.15 | -$1.15 |
| **TOTAL** | **$8.05** | **$1.97** | **$6.08 (76%)** |

## Security Considerations

After retiring EC2:
- No more Fail2ban (IP-based DDoS protection)
- No more SSH access (no vulnerability vector)
- WAF provides DDoS protection (FASE 5)
- API throttling prevents abuse

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Application down after EC2 delete | Check DNS resolution, CloudFront is caching |
| CloudFront returning 502 | Check Lambda logs, API Gateway integration |
| Slow response after migration | CloudFront cache is warming up, wait 5 min |
| AWS bill still showing EC2 | Verify instance fully terminated, check previous month bill |

## Post-Retirement Cleanup

### 1. Archive old infrastructure code
```bash
git mv terraform/ec2.tf terraform/RETIRED-ec2.tf.bak
git mv ansible/ RETIRED-ansible.bak/
git commit -m "FASE 8: Archive old EC2/Ansible infrastructure"
```

### 2. Document migration
```bash
cat > MIGRATION_NOTES.md << EOF
# CloudCV Migration Complete (FASE 8)

## Timeline
- FASE 1: Analysis (AWS 7R strategy evaluation)
- FASE 2: S3 + CloudFront (static assets, 94% cost reduction)
- FASE 3: Lambda + DynamoDB (dynamic API, 79% cost reduction)
- FASE 4: ECS Fargate Spot (complex backend, optional)
- FASE 5: WAF + Security (DDoS protection, optional)
- FASE 6: Assets upload (validation)
- FASE 7: Cost analysis (monitoring)
- FASE 8: EC2 retirement (79% cost savings achieved)

## Final Costs
- Original: $8.05/month
- After migration: $1.97/month
- Savings: $6.08/month (76%)

## Lessons Learned
1. Serverless is cheaper for low-traffic applications
2. CloudFront caching is critical for cost optimization
3. Pay-per-request DynamoDB better than provisioned capacity
4. Lambda layers improve code organization
5. Terraform IaC beats manual management

## Rollback Plan
If needed to revert:
1. EC2 instance can be re-launched from backup
2. Ansible playbooks available in RETIRED-ansible.bak/
3. DNS can be switched back to Elastic IP
4. Cost: ~$8.05/month again
EOF

git add MIGRATION_NOTES.md
git commit -m "FASE 8: Complete - Add migration documentation"
```

### 3. Update README
```bash
# Update README.md with:
- CloudCV is now serverless (no EC2)
- Costs reduced 76% to $1.97/month
- Infrastructure managed by Terraform
- See terraform/FASE*_*.md for architecture details
```

## Completion Checklist

- [ ] EC2 instance terminated
- [ ] Elastic IP released
- [ ] Security groups deleted
- [ ] IAM EC2 roles deleted
- [ ] DNS pointing to CloudFront
- [ ] Application working from browser
- [ ] API endpoints responsive
- [ ] CloudWatch logs show no errors
- [ ] AWS bill reflects $1.97/month (wait for billing cycle)
- [ ] Old Terraform files archived
- [ ] Migration documented
- [ ] README updated

## Success Criteria

✅ **FASE 8 COMPLETE** when:
1. Zero EC2 instances running
2. Zero Elastic IPs allocated
3. Application fully functional via CloudFront + Lambda
4. Next AWS bill shows $1.97/month cost
5. No alarms or errors in CloudWatch

## Summary

**CloudCV successfully migrated from EC2 to serverless architecture.**

- **Cost**: $8.05 → $1.97/month (76% savings)
- **Reliability**: Single EC2 → Multi-AZ Lambda + S3 + CloudFront
- **Operations**: Manual Ansible → Terraform IaC
- **Performance**: ~500ms API latency → < 100ms cached

**Migration complete in 8 phases over ~2-3 days of work.**

