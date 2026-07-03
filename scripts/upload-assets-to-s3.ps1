# Upload web assets to S3 bucket for CloudFront delivery

$BucketName = "example-cloudcv-assets-002645520899"
$AssetDir = "web"
$DistributionId = "E223J1QGG2SX9M"

Write-Host "Uploading assets to S3..." -ForegroundColor Green

# Upload all web assets
aws s3 sync $AssetDir s3://$BucketName/ --cache-control "public, max-age=3600" --region eu-west-1

# Invalidate CloudFront cache
Write-Host "Invalidating CloudFront cache..." -ForegroundColor Yellow
aws cloudfront create-invalidation --distribution-id $DistributionId --paths "/*" --region eu-west-1

Write-Host "Done! Assets available at:" -ForegroundColor Green
Write-Host "https://lnoval.dev/" -ForegroundColor Cyan
Write-Host "https://dq8zmgoscvrxi.cloudfront.net/" -ForegroundColor Cyan
