// This is the main entry point to the module.
//
// All supported sources are allowed in a validation rule in `var.sources` variable.
//
// When adding a new source, add a new block to `local.source_defaults`  with it's default values.
//
// If a source requires additional resources not coverd by the generic `audit-lambda` module,
// put these resources in a separate file named after the source, e.g. `terraform_cloud.tf`.
//
locals {
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
  lambda_policy        = try(each.value.lambda_policy, null)
  lambda_source_path   = "${path.module}/lambdas/${each.key}"
  object_locking       = var.object_locking
  scheduled_time       = var.scheduled_time
  secret_name          = try(each.value.secret_name, "/audit-log-tokens/${each.key}")
  service_name         = each.value.service_name
  tags                 = try(merge(var.tags, each.value.tags), null)
}
