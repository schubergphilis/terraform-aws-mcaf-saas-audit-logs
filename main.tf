// This is the main entry point to the module.
//
// All supported sources are allowed in a validation rule in `var.sources` variable.
//
// When adding a new source, add a new block to `local.source_defaults`  with it's default values.
//
// If a source requires additional resources not coverd by the generic `audit-lambda` module,
// put these resources in a separate file named after the source, e.g. `terraform-cloud.tf`.
//
locals {
  bucket_lifecycle_rules = {
    basic = {
      id                                = "basic"
      enabled                           = true
      abort_incomplete_multipart_upload = { days_after_initiation = 3 }
      expiration                        = { days = 730 }
      noncurrent_version_expiration     = { noncurrent_days = 7 }
    }
    one-year-tiered = {
      id                                = "one-year-tiered"
      enabled                           = true
      abort_incomplete_multipart_upload = { days_after_initiation = 3 }
      expiration                        = { days = 365 }
      noncurrent_version_expiration     = { noncurrent_days = 30 }
      transition                        = { days = 90, storage_class = "GLACIER_IR" }
    }
  }

  create_bucket = var.create_bucket == true && var.create_bucket_per_source == false && var.created_bucket_names == null

  created_bucket_names = local.create_bucket ? {
    audit_logs     = module.bucket_for_audit_logs[0].name
    lambda_package = module.bucket_for_lambda_package[0].name
  } : {}

  source_defaults = {
    gitlab = {
      api_url      = "https://gitlab.com/api/v4"
      service_name = "GitLab"
    }

    okta = {
      service_name = "Okta"
    }

    terraform-cloud = {
      api_url           = "https://app.terraform.io/api/v2/organization/audit-trail"
      dead_letter_queue = try(aws_sqs_queue.terraform_cloud_audit_log_dlq[0].arn, null)
      environment       = try({ QUEUE_URL = aws_sqs_queue.terraform_cloud_audit_log[0].id }, null)
      lambda_policy     = try(data.aws_iam_policy_document.terraform_cloud[0].json, null)
      service_name      = "Terraform Cloud"
    }
  }

  sources_no_null = {
    for source, config in var.sources : source => { for name, value in config : name => value if value != null }
  }

  sources = {
    for source, config in local.sources_no_null :
    source => merge(local.source_defaults[source], config)
  }
}

data "aws_caller_identity" "current" {}

module "bucket_for_audit_logs" {
  count = local.create_bucket ? 1 : 0

  source  = "schubergphilis/mcaf-s3/aws"
  version = "~> 0.14.1"

  name              = "${var.bucket_base_name}-${data.aws_caller_identity.current.account_id}"
  kms_key_arn       = var.kms_key_arn
  lifecycle_rule    = [local.bucket_lifecycle_rules["one-year-tiered"]]
  object_lock_mode  = var.object_locking.mode
  object_lock_years = var.object_locking.years
  versioning        = true
  tags              = var.tags

  logging = {
    target_bucket = module.bucket_for_access_logs[0].name
    target_prefix = "access-logs/"
  }
}

module "bucket_for_access_logs" {
  count = local.create_bucket ? 1 : 0

  source  = "schubergphilis/mcaf-s3/aws"
  version = "~> 0.14.1"

  name                       = "${var.bucket_base_name}-access-logs-${data.aws_caller_identity.current.account_id}"
  kms_key_arn                = var.kms_key_arn
  lifecycle_rule             = [local.bucket_lifecycle_rules["one-year-tiered"]]
  logging_source_bucket_arns = [module.bucket_for_audit_logs[0].arn]
  versioning                 = true
  tags                       = var.tags
}

module "bucket_for_lambda_package" {
  count = local.create_bucket ? 1 : 0

  source  = "schubergphilis/mcaf-s3/aws"
  version = "~> 0.14.1"

  name           = "${var.bucket_base_name}-lambda-${data.aws_caller_identity.current.account_id}"
  kms_key_arn    = var.kms_key_arn
  lifecycle_rule = [local.bucket_lifecycle_rules["basic"]]
  versioning     = true
  tags           = var.tags
}

module "lambda" {
  for_each = local.sources

  source = "./modules/audit-lambda"

  api_token            = each.value.api_token
  api_url              = each.value.api_url
  bucket_base_name     = var.create_bucket_per_source ? try(each.value.bucket_base_name, "${each.key}-audit-logs") : var.bucket_base_name
  bucket_prefix        = try(each.value.bucket_prefix, each.key)
  compress_audit_logs  = try(each.value.compress_audit_logs, var.compress_audit_logs)
  create_bucket        = local.create_bucket != true
  created_bucket_names = var.created_bucket_names != null ? var.created_bucket_names : local.created_bucket_names
  dead_letter_queue    = try(each.value.dead_letter_queue, null)
  environment          = try(each.value.environment, null)
  kms_key_arn          = var.kms_key_arn
  lambda_log_level     = each.value.lambda_log_level
  lambda_log_retention = var.lambda_log_retention
  lambda_memory_size   = try(each.value.lambda_memory_size, null)
  lambda_name          = try(each.value.lambda_name, "${each.key}-audit-log-fetcher")
  lambda_pkg_path      = "${path.module}/lambdas/${each.key}/pkg/lambda_function_${var.python_version}.zip"
  lambda_policy        = try(each.value.lambda_policy, null)
  object_locking       = var.object_locking
  scheduled_time       = var.scheduled_time
  secret_name          = try(each.value.secret_name, "/audit-log-tokens/${each.key}")
  service_name         = each.value.service_name
  tags                 = try(merge(var.tags, each.value.tags), null)
}
