data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "archive_file" "lambda_s3_url_file" {
  type        = "zip"
  source_file = "lambda-s3-url.py"
  output_path = "lambda-s3-url.zip"
}

data "archive_file" "lambda_custom_url_file" {
  type        = "zip"
  source_file = "lambda-custom-url.py"
  output_path = "lambda-custom-url.zip"
}

data "klayers_package_latest_version" "crypto" {
  name           = "cryptography"
  region         = "us-east-1"
  python_version = "3.12-arm64"
}

data "aws_route53_zone" "jwwdev_net" {
  name         = "jwwdev.net."
  private_zone = false
}
