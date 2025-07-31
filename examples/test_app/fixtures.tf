locals {
  index_pattern    = "/index.html"
  application_name = "helper-cf-s3-example"
  project          = "constr"
  stage            = "acc"

  tags = {
    module  = "terraform-aws-helper-cloudfront-s3"
    testing = "true"
  }
}

data "aws_cloudfront_cache_policy" "managed" {
  provider = aws.default
  name     = "Managed-CachingOptimized"
}

data "aws_cloudfront_cache_policy" "managed_index" {
  provider = aws.default
  name     = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "managed" {
  provider = aws.default
  name     = "Managed-CORS-S3Origin"
}

data "aws_cloudfront_response_headers_policy" "managed" {
  provider = aws.default
  name     = "Managed-CORS-with-preflight-and-SecurityHeadersPolicy"
}

data "aws_iam_policy_document" "lambda_at_edge" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "lambda.amazonaws.com",
        "ec2.amazonaws.com",
        "edgelambda.amazonaws.com"
      ]
    }
  }
}
resource "aws_iam_role" "lambda_at_edge" {
  name = "helper-cf-s3-example"

  assume_role_policy = data.aws_iam_policy_document.lambda_at_edge.json

  tags = local.tags
}
resource "aws_iam_role_policy_attachment" "lambda_at_edge" {
  role       = aws_iam_role.lambda_at_edge.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


provider "aws" {
  region = "us-east-1"
  alias  = "useast1"
}

module "lambda_at_edge" {
  source = "../../modules/lambda@edge"

  providers = { aws = aws.useast1 }

  role_arn = aws_iam_role.lambda_at_edge.arn
  functions = {
    "${local.project}-${local.application_name}-originrequest" = {
      source = [{
        content  = <<-EOT
        'use strict';

        exports.handler = (event, context, callback) => {

          //Get contents of response
          const response = event.Records[0].cf.response;
          const headers = response.headers;

          //Set new headers
          headers['strict-transport-security'] = [{key: 'Strict-Transport-Security', value: 'max-age=63072000; includeSubdomains; preload'}];
          headers['content-security-policy'] = [{key: 'Content-Security-Policy', value: "default-src 'self' foobar.constr.acc.guidion.io;"}];
          headers['x-content-type-options'] = [{key: 'X-Content-Type-Options', value: 'nosniff'}];
          headers['x-frame-options'] = [{key: 'X-Frame-Options', value: 'DENY'}];
          headers['x-xss-protection'] = [{key: 'X-XSS-Protection', value: '1; mode=block'}];
          headers['referrer-policy'] = [{key: 'Referrer-Policy', value: 'same-origin'}];

          //Return modified response
          callback(null, response);
        };
        EOT
        filename = "index.js"
      }]
      runtime      = "nodejs18.x"
      handler      = "index.handler"
      event_type   = "origin-response"
      include_body = false
    }
  }
}
