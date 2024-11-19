resource "aws_s3_bucket" "download_bucket" {
  bucket        = "my-download-bucket"
  force_destroy = true
}

resource "aws_s3_object" "hello_zip" {
  bucket = aws_s3_bucket.download_bucket.bucket
  key    = "hello.zip" # S3 key (filename in the bucket)
  source = "test.zip"  # Path to the local file to upload
}


resource "aws_s3_object" "hello_txt" {
  bucket = aws_s3_bucket.download_bucket.bucket
  key    = "hello.txt" # S3 key (filename in the bucket)
  source = "test.txt"  # Path to the local file to upload
}





resource "aws_lambda_function" "presigned_s3_url" {
  function_name    = "presigned_s3_url"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "lambda-s3-url.lambda_handler"
  runtime          = "python3.12" # Or your preferred runtime
  filename         = data.archive_file.lambda_s3_url_file.output_path
  source_code_hash = data.archive_file.lambda_s3_url_file.output_base64sha256
  architectures    = ["arm64"]
  timeout          = 15

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.download_bucket.bucket
    }
  }
}

resource "aws_lambda_function" "presigned_custom_url" {
  function_name    = "presigned_custom_url"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "lambda-custom-url.lambda_handler"
  runtime          = "python3.12" # Or your preferred runtime
  filename         = data.archive_file.lambda_custom_url_file.output_path
  source_code_hash = data.archive_file.lambda_custom_url_file.output_base64sha256
  architectures    = ["arm64"]
  timeout          = 15

  layers = [
    data.klayers_package_latest_version.crypto.arn
  ]

  environment {
    variables = {
      BUCKET_NAME           = aws_s3_bucket.download_bucket.bucket
      CLOUDFRONT_DOMAIN     = aws_route53_record.download_bucket_cname.name
      SECRET_NAME           = aws_secretsmanager_secret.cloudfront_private_key.name
      KEY_PAIR_ID_PARAMETER = aws_ssm_parameter.cloudfront_key_id.name
    }
  }
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Action" : "sts:AssumeRole",
      "Principal" : {
        "Service" : "lambda.amazonaws.com"
      },
      "Effect" : "Allow"
    }]
  })
}







resource "aws_iam_policy" "read_cloudfront_private_key" {
  name        = "ReadCloudFrontPrivateKeyPolicy"
  description = "Policy to allow Lambda to read the CloudFront private key from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Resource = aws_secretsmanager_secret.cloudfront_private_key.arn
      }
    ]
  })
}


resource "aws_iam_policy" "read_ssm_key_pair_id" {
  name        = "ReadCloudFrontKeyPairIDPolicy"
  description = "Policy to allow Lambda to read the CloudFront Key Pair ID from SSM Parameter Store"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameterHistory"
        ],
        Resource = aws_ssm_parameter.cloudfront_key_id.arn
      }
    ]
  })
}

# Attach the policies to the Lambda execution role
resource "aws_iam_role_policy_attachment" "lambda_exec_role_ssm_access" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.read_ssm_key_pair_id.arn
}

resource "aws_iam_role_policy_attachment" "lambda_exec_role_secret_access" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.read_cloudfront_private_key.arn
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}













resource "aws_apigatewayv2_api" "api_gateway" {
  name          = "my-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api_gateway.id
  name        = "$default"
  auto_deploy = true
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_presigning.arn
    format          = jsonencode({ "requestId" : "$context.requestId", "ip" : "$context.identity.sourceIp", "requestTime" : "$context.requestTime", "httpMethod" : "$context.httpMethod", "routeKey" : "$context.routeKey", "status" : "$context.status", "protocol" : "$context.protocol", "responseLength" : "$context.responseLength" })
  }
}

resource "aws_cloudwatch_log_group" "api_gateway_presigning" {
  name              = "apigw-signing"
  retention_in_days = 1
}




resource "aws_apigatewayv2_integration" "lambda_s3_url_integration" {
  api_id                 = aws_apigatewayv2_api.api_gateway.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.presigned_s3_url.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "lambda_s3_url_route" {
  api_id             = aws_apigatewayv2_api.api_gateway.id
  route_key          = "GET /presigned-s3-url"
  target             = "integrations/${aws_apigatewayv2_integration.lambda_s3_url_integration.id}"
  authorization_type = "NONE"
}
resource "aws_lambda_permission" "allow_apigw_s3_url" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.presigned_s3_url.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api_gateway.execution_arn}/*"
}






resource "aws_apigatewayv2_integration" "lambda_custom_url_integration" {
  api_id                 = aws_apigatewayv2_api.api_gateway.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.presigned_custom_url.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "lambda_custom_url_route" {
  api_id             = aws_apigatewayv2_api.api_gateway.id
  route_key          = "GET /presigned-custom-url"
  target             = "integrations/${aws_apigatewayv2_integration.lambda_custom_url_integration.id}"
  authorization_type = "NONE"
}

resource "aws_lambda_permission" "allow_apigw_custom_url" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.presigned_custom_url.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api_gateway.execution_arn}/*"
}












resource "aws_acm_certificate" "cloudfront_cert" {
  provider          = aws.us_east_1
  domain_name       = "my-download-bucket.jwwdev.net"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_cloudfront_public_key" "cloudfront_public_key" {
  name        = "my-cloudfront-public-key"
  encoded_key = file("pubkey.pem")
  comment     = "Public key for CloudFront signed URLs"
}

resource "aws_cloudfront_key_group" "cloudfront_key_group" {
  name  = "my-cloudfront-key-group"
  items = [aws_cloudfront_public_key.cloudfront_public_key.id]
}






# DNS Validation using Route53
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cloudfront_cert.domain_validation_options : dvo.domain_name => {
      name    = dvo.resource_record_name
      type    = dvo.resource_record_type
      value   = dvo.resource_record_value
      zone_id = data.aws_route53_zone.jwwdev_net.zone_id
    }
  }

  allow_overwrite = true
  name            = each.value.name
  type            = each.value.type
  zone_id         = each.value.zone_id
  records         = [each.value.value]
  ttl             = 60
}

# Wait for certificate validation
resource "aws_acm_certificate_validation" "cloudfront_cert_validation" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cloudfront_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Access identity for CloudFront to access the S3 bucket"
}

resource "aws_s3_bucket_policy" "cloudfront_policy" {
  bucket = aws_s3_bucket.download_bucket.id

  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Sid : "AllowCloudFrontServicePrincipalReadOnly",
        Effect : "Allow",
        Principal : {
          AWS = aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn
        },
        Action   = ["s3:GetObject"],
        Resource = ["${aws_s3_bucket.download_bucket.arn}/*"]
      }
    ]
  })
}


resource "aws_cloudfront_distribution" "my_distribution" {
  origin {
    domain_name = aws_s3_bucket.download_bucket.bucket_regional_domain_name
    origin_id   = "S3-my-download-bucket"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = false
  default_root_object = "index.html" # Customize if needed

  aliases = ["my-download-bucket.jwwdev.net"] # Custom domain name

  default_cache_behavior {
    target_origin_id       = "S3-my-download-bucket"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    forwarded_values {
      query_string = true
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cloudfront_cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2019"
  }

  # Add ordered_cache_behavior with trusted_key_groups
  ordered_cache_behavior {
    path_pattern           = "/hello.*" # Adjust the path pattern as needed
    target_origin_id       = "S3-my-download-bucket"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    forwarded_values {
      query_string = true
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 30
    max_ttl     = 60

    trusted_key_groups = [aws_cloudfront_key_group.cloudfront_key_group.id]
  }
}


resource "aws_route53_record" "download_bucket_cname" {
  zone_id         = data.aws_route53_zone.jwwdev_net.zone_id
  name            = "my-download-bucket.jwwdev.net"
  type            = "CNAME"
  ttl             = 60
  allow_overwrite = true
  records         = [aws_cloudfront_distribution.my_distribution.domain_name]
}



resource "aws_secretsmanager_secret" "cloudfront_private_key" {
  name                           = "cloudfront-private-key"
  description                    = "Private key for CloudFront signed URL generation"
  force_overwrite_replica_secret = true
  recovery_window_in_days        = 0
}

resource "aws_secretsmanager_secret_version" "cloudfront_private_key_version" {
  secret_id     = aws_secretsmanager_secret.cloudfront_private_key.id
  secret_string = file("key.pem")
}

resource "aws_ssm_parameter" "cloudfront_key_id" {
  name  = "cloudfront_key_id"
  type  = "String"
  value = aws_cloudfront_public_key.cloudfront_public_key.id
}








output "api_gateway_endpoint" {
  value = aws_apigatewayv2_api.api_gateway.api_endpoint
}

output "s3_endpoint_name" {
  value = aws_s3_bucket.download_bucket.bucket_regional_domain_name
}
