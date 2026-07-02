# Build Lambda function ZIP files for FASE 5
# Usage: .\scripts\build-lambda-zips.ps1

Set-Location (Split-Path -Parent (Split-Path -Parent $PSCommandPath))

Write-Host "Building Lambda function ZIP files..." -ForegroundColor Green

$lambdaFunctions = @(
    @{Path = "lambda/cv_handler"; Output = "terraform/lambda_cv_handler.zip"},
    @{Path = "lambda/visit_counter"; Output = "terraform/lambda_visit_counter.zip"},
    @{Path = "lambda/projects_handler"; Output = "terraform/lambda_projects_handler.zip"},
    @{Path = "lambda/api_authorizer"; Output = "terraform/lambda_api_authorizer.zip"}
)

$allSuccess = $true
foreach ($lambda in $lambdaFunctions) {
    $functionPath = $lambda.Path
    $outputPath = $lambda.Output

    if (-not (Test-Path $functionPath)) {
        Write-Host "ERROR: $functionPath not found!" -ForegroundColor Red
        $allSuccess = $false
        continue
    }

    if (Test-Path $outputPath) {
        Remove-Item $outputPath -Force
    }

    $indexFile = Join-Path $functionPath "index.py"
    if (Test-Path $indexFile) {
        Compress-Archive -Path $indexFile -DestinationPath $outputPath -Force
        Write-Host "OK: $outputPath" -ForegroundColor Green
    } else {
        Write-Host "ERROR: index.py not found in $functionPath" -ForegroundColor Red
        $allSuccess = $false
    }
}

if ($allSuccess) {
    Write-Host "`nAll Lambda ZIPs built successfully!" -ForegroundColor Green
    Write-Host "Next step: terraform plan" -ForegroundColor Cyan
} else {
    Write-Host "`nERROR: Some Lambda ZIPs failed!" -ForegroundColor Red
    exit 1
}
