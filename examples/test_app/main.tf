variable "project" {}
variable "stage" {}
variable "application_name" {}
variable "parent_zone" {}

provider "aws" {
  region = "eu-west-1"
  alias  = "default"
}

module "cloudfront_s3" {
  source = "../../"

  providers = {
    aws = aws.default
  }

  namespace                           = var.project
  stage                               = var.stage
  name                                = var.application_name
  dns_alias_enabled                   = true
  parent_zone_name                    = var.parent_zone
  acm_certificate_arn                 = ""
  additional_tag_map                  = { "testing_tags" = "test" }
  allowed_methods                     = ["HEAD", "GET"]
  cors_allowed_origins                = ["aux-1.constr.acc.guidion.io"]
  cors_allowed_methods                = ["HEAD", "GET"]
  cache_policy_id                     = data.aws_cloudfront_cache_policy.managed.id
  origin_request_policy_id            = data.aws_cloudfront_origin_request_policy.managed.id
  default_ttl                         = 60
  max_ttl                             = 31536000
  lambda_function_association         = module.lambda_at_edge.lambda_function_association
  cloudfront_access_log_create_bucket = false
  cloudfront_access_logging_enabled   = false
  block_origin_public_access_enabled  = true
  web_acl_id                          = ""

  custom_error_response = [{
    error_caching_min_ttl = "10",
    error_code            = "404",
    response_code         = "200",
    response_page_path    = local.index_pattern
  }]

  # Different cache for index (local.index_pattern)
  ordered_cache = [{
    target_origin_id                  = ""
    path_pattern                      = local.index_pattern
    allowed_methods                   = ["HEAD", "GET"]
    cached_methods                    = ["HEAD", "GET"]
    compress                          = true
    cache_policy_id                   = data.aws_cloudfront_cache_policy.managed_index.id
    origin_request_policy_id          = data.aws_cloudfront_origin_request_policy.managed.id
    min_ttl                           = 0
    default_ttl                       = 0
    max_ttl                           = 0
    forward_query_string              = true
    forward_header_values             = []
    forward_cookies                   = "all"
    lambda_function_association       = module.lambda_at_edge.lambda_function_association
    response_headers_policy_id        = data.aws_cloudfront_response_headers_policy.managed.id
    function_association              = []
    trusted_key_groups                = []
    trusted_signers                   = []
    viewer_protocol_policy            = "redirect-to-https"
    forward_cookies_whitelisted_names = []
  }]
}
