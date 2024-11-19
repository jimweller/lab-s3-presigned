# Variables
$API_ENDPOINT = tofu output -raw api_gateway_endpoint
$ROUTE_KEY_CUSTOM = "presigned-custom-url"
$ROUTE_KEY_S3 = "presigned-s3-url"
$S3_ENDPOINT = tofu output -raw s3_endpoint_name
$FILENAME = "hello.zip"

# Test unsigned S3 URL (expected to fail)
Write-Host "Use unsigned S3 URL (should fail) from:" -ForegroundColor Yellow
$unsignedUrl = "https://$S3_ENDPOINT/$FILENAME"
Write-Host $unsignedUrl
Invoke-RestMethod -Uri $unsignedUrl -Method Get -ErrorAction SilentlyContinue | Out-String
Write-Host "`n"

# Get presigned S3 URL
Write-Host "Getting presigned S3 URL from:" -ForegroundColor Yellow
$s3Url = "$API_ENDPOINT/$ROUTE_KEY_S3"
Write-Host "$s3Url for $FILENAME"
$response = Invoke-RestMethod -Uri $s3Url -Method Get -Body @{ filename = $FILENAME }
$presignedUrlS3 = $response.url

Write-Host "Presigned S3 URL:" -ForegroundColor Yellow
Write-Host $presignedUrlS3.Substring(0, [Math]::Min(100, $presignedUrlS3.Length)) + "..."
Write-Host "`n"

# Download file using presigned S3 URL
Write-Host "Downloading $FILENAME" -ForegroundColor Yellow
Invoke-WebRequest -Uri $presignedUrlS3 -OutFile $FILENAME

# Unzip the file
Write-Host "Unzipping $FILENAME" -ForegroundColor Yellow
Expand-Archive -Path $FILENAME -DestinationPath "$PWD/unzipped" -Force
Get-ChildItem -Path "$PWD/unzipped"

# Remove the downloaded zip file
Remove-Item -Path $FILENAME -Force
Remove-Item -Recurse -Path $PWD/unzipped -Force

# Get presigned CloudFront URL
Write-Host "`nGetting presigned CloudFront URL from:" -ForegroundColor Yellow
$cloudFrontUrl = "$API_ENDPOINT/$ROUTE_KEY_CUSTOM"
Write-Host "$cloudFrontUrl for $FILENAME"
$response = Invoke-RestMethod -Uri $cloudFrontUrl -Method Get -Body @{ filename = $FILENAME }
$presignedUrlCloudFront = $response.url

Write-Host "Presigned CloudFront URL:" -ForegroundColor Yellow
Write-Host $presignedUrlCloudFront.Substring(0, [Math]::Min(100, $presignedUrlCloudFront.Length)) + "..."
Write-Host "`n"

# Download file using presigned CloudFront URL
Write-Host "Downloading $FILENAME" -ForegroundColor Yellow
Invoke-WebRequest -Uri $presignedUrlCloudFront -OutFile $FILENAME

# Unzip the file
Write-Host "Unzipping $FILENAME" -ForegroundColor Yellow
Expand-Archive -Path $FILENAME -DestinationPath "$PWD/unzipped" -Force
Get-ChildItem -Path "$PWD/unzipped"

# Remove the downloaded zip file
Remove-Item -Path $FILENAME -Force
Remove-Item -Recurse -Path $PWD/unzipped -Force
