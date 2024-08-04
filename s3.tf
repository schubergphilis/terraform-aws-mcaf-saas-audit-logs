locals {
  bucket_lifecycle_rules = {
    basic = {
      id                                = "basic"
      enabled                           = true
      abort_incomplete_multipart_upload = { days_after_initiation = 7 }
      expiration                        = { expired_object_delete_marker = true }
      noncurrent_version_expiration     = { noncurrent_days = 7 }
    }
    one-year-tiered = {
      id                                = "one-year-tiered"
      enabled                           = true
      abort_incomplete_multipart_upload = { days_after_initiation = 14 }
      expiration                        = { days = 365 }
      noncurrent_version_expiration     = { noncurrent_days = 365 }
      noncurrent_version_transition     = { noncurrent_days = 90, storage_class = "INTELLIGENT_TIERING" }
      transition                        = { days = 90, storage_class = "INTELLIGENT_TIERING" }
    }
  }

  create_bucket = var.create_bucket == true && var.create_bucket_per_source == false && var.created_bucket_names == null

  created_bucket_names = local.create_bucket ? {
    audit_logs     = module.bucket_for_audit_logs[0].name
    lambda_package = module.bucket_for_lambda_package[0].name
  } : {}
}

data "aws_caller_identity" "current" {}

module "bucket_for_audit_logs" {
  count = local.create_bucket ? 1 : 0

  source  = "schubergphilis/mcaf-s3/aws"
  version = "~> 0.13.1"

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
  version = "~> 0.13.1"

  name              = "${var.bucket_base_name}-access-logs-${data.aws_caller_identity.current.account_id}"
  kms_key_arn       = var.kms_key_arn
  lifecycle_rule    = [local.bucket_lifecycle_rules["one-year-tiered"]]
  object_lock_mode  = var.object_locking.mode
  object_lock_years = var.object_locking.years
  versioning        = true
  tags              = var.tags
}

module "bucket_for_lambda_package" {
  count = local.create_bucket ? 1 : 0

  source  = "schubergphilis/mcaf-s3/aws"
  version = "~> 0.13.1"

  name           = "${var.bucket_base_name}-lambda-${data.aws_caller_identity.current.account_id}"
  kms_key_arn    = var.kms_key_arn
  lifecycle_rule = [local.bucket_lifecycle_rules["basic"]]
  versioning     = true
  tags           = var.tags
}
