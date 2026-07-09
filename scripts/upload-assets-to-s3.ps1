# Upload web assets to S3 bucket for CloudFront delivery
# HTML is uploaded with no-cache so browsers always revalidate;
# everything else gets 1 hour of browser cache.

$BucketName = "example-cloudcv-assets-002645520899"
$AssetDir = "web"
$DistributionId = "E223J1QGG2SX9M"

Write-Host "Uploading static assets (1h browser cache)..." -ForegroundColor Green
aws s3 sync $AssetDir s3://$BucketName/ --exclude "*.html" --cache-control "public, max-age=3600" --region eu-west-1

Write-Host "Uploading HTML (no-cache)..." -ForegroundColor Green
aws s3 sync $AssetDir s3://$BucketName/ --exclude "*" --include "*.html" --cache-control "no-cache" --region eu-west-1

Write-Host "Invalidating CloudFront cache..." -ForegroundColor Yellow
aws cloudfront create-invalidation --distribution-id $DistributionId --paths "/*" --region eu-west-1

Write-Host "Done! Assets available at:" -ForegroundColor Green
Write-Host "https://lnoval.dev/" -ForegroundColor Cyan
