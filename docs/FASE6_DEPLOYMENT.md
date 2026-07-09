# FASE 6: Assets Upload and End-to-End Validation

## Objective

Upload all assets to S3 and validate end-to-end functionality.

## Steps

### 1. Prepare Assets
```bash
cd web/portfolio
ls -la
# Should contain: index.html, styles/, scripts/, assets/
```

### 2. Upload to S3
```bash
S3_BUCKET=$(terraform output -raw s3_assets_bucket)

# Upload HTML
aws s3 cp web/portfolio/index.html s3://$S3_BUCKET/index.html --cache-control "max-age=0"

# Upload CSS
aws s3 cp web/portfolio/styles/ s3://$S3_BUCKET/styles/ --recursive --cache-control "max-age=86400"

# Upload JS
aws s3 cp web/portfolio/scripts/ s3://$S3_BUCKET/scripts/ --recursive --cache-control "max-age=86400"

# Upload Assets
aws s3 cp web/portfolio/assets/ s3://$S3_BUCKET/assets/ --recursive --cache-control "max-age=86400"

# Upload CV files
aws s3 cp --recursive cv/ s3://$S3_BUCKET/cv/ --cache-control "max-age=0"
```

### 3. Validate CloudFront Caching
```bash
# Test cache hit
curl -I https://lnoval.dev
# Should return: X-Cache: Hit from cloudfront

# Invalidate cache if needed
aws cloudfront create-invalidation \
  --distribution-id $(terraform output -raw cloudfront_distribution_id) \
  --paths "/*"
```

### 4. Test API Endpoints
```bash
API_URL=$(terraform output -raw api_invoke_url)

# Test health
curl $API_URL/health

# Test CV retrieval
curl $API_URL/cv/en

# Test projects list
curl $API_URL/projects

# Test visit tracking
curl -X POST $API_URL/visits \
  -H "Content-Type: application/json" \
  -d '{"page_id": "portfolio"}'
```

### 5. Verify DynamoDB Data
```bash
# Check CV cache table
aws dynamodb scan --table-name lnoval-cv-cv-cache

# Check visits table
aws dynamodb scan --table-name lnoval-cv-visits
```

### 6. Browser Testing
1. Open https://lnoval.dev
2. Check console for errors
3. Click "View CV" - should fetch from API
4. Check DevTools Network tab - should see API calls
5. Verify response times < 500ms

## Checklist

- [ ] All assets uploaded to S3
- [ ] CloudFront cache headers correct
- [ ] API endpoints responding (200)
- [ ] DynamoDB tables populated
- [ ] Browser loads without errors
- [ ] API calls complete in < 500ms
- [ ] Visit tracking working (POST /visits returns 200)

## Troubleshooting

| Issue | Solution |
|-------|----------|
| 403 Forbidden from S3 | Check S3 bucket policy, OAI permissions |
| API returns 502 | Check Lambda logs, IAM permissions |
| Slow response (>1s) | Check CloudFront cache, Lambda cold start |
| DynamoDB empty | Check Lambda puts data correctly |

## Next Steps

→ FASE 7: Cost analysis and optimization

