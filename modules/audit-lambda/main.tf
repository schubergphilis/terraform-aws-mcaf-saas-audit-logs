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

  bucket_prefix = trim(var.bucket_prefix, "/")

  bucket_for_audit_logs     = var.create_bucket ? module.bucket_for_audit_logs[0] : data.aws_s3_bucket.bucket["audit_logs"]
  bucket_for_lambda_package = var.create_bucket ? module.bucket_for_lambda_package[0] : data.aws_s3_bucket.bucket["lambda_package"]

  scheduled_time       = split(":", var.scheduled_time)
  scheduled_expression = "cron(${tonumber(local.scheduled_time[1])} ${tonumber(local.scheduled_time[0])} ? * * *)"
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_s3_bucket" "bucket" {
  for_each = var.created_bucket_names != null ? var.created_bucket_names : {}

  bucket = each.value
}

data "aws_iam_policy_document" "iam_policy" {
  # checkov:skip=CKV_AWS_111: Access should be limited on KMS key
  # checkov:skip=CKV_AWS_356: Access should be limited on KMS key

  source_policy_documents = compact([var.lambda_policy])

  statement {
    sid       = "AllowKMSEncryptDecrypt"
    resources = ["*"]

    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*",
    ]
  }

  statement {
    sid       = "AllowS3UploadToBucket"
    actions   = ["s3:PutObject"]
    resources = ["${local.bucket_for_audit_logs.arn}/${local.bucket_prefix}/*"]
  }

  statement {
    sid       = "AllowCloudWatchPutLogEvents"
    resources = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"]

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
  }

  statement {
    sid       = "AllowSecretsManagerGetSecret"
    resources = [aws_secretsmanager_secret.token.arn]

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
  }
}

resource "aws_cloudwatch_event_rule" "trigger" {
  name                = "audit-trigger-daily"
  description         = "Triggers audit lambdas daily"
  schedule_expression = local.scheduled_expression
  tags                = var.tags
}

resource "aws_cloudwatch_event_target" "trigger" {
  arn       = module.lambda.arn
  rule      = aws_cloudwatch_event_rule.trigger.name
  target_id = module.lambda.name

  dynamic "dead_letter_config" {
    for_each = var.dead_letter_queue != null ? [var.dead_letter_queue] : []

    content {
      arn = var.dead_letter_queue
    }
  }

  retry_policy {
    maximum_retry_attempts       = 3
    maximum_event_age_in_seconds = 60
  }
}

resource "aws_lambda_permission" "allow_cloudwatch_to_invoke_lambda" {
  statement_id  = "AllowLambdaExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda.name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.trigger.arn
}

module "bucket_for_audit_logs" {
  count = var.create_bucket ? 1 : 0

  source  = "schubergphilis/mcaf-s3/aws"
  version = "~> 0.14.1"

  name_prefix       = var.bucket_base_name
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
  count = var.create_bucket ? 1 : 0

  source  = "schubergphilis/mcaf-s3/aws"
  version = "~> 0.14.1"

  name_prefix                = "${var.bucket_base_name}-access-logs"
  kms_key_arn                = var.kms_key_arn
  lifecycle_rule             = [local.bucket_lifecycle_rules["one-year-tiered"]]
  logging_source_bucket_arns = [module.bucket_for_audit_logs[0].arn]
  versioning                 = true
  tags                       = var.tags
}

module "bucket_for_lambda_package" {
  count = var.create_bucket ? 1 : 0

  source  = "schubergphilis/mcaf-s3/aws"
  version = "~> 0.14.1"

  name_prefix    = "${var.bucket_base_name}-lambda"
  kms_key_arn    = var.kms_key_arn
  lifecycle_rule = [local.bucket_lifecycle_rules["basic"]]
  versioning     = true
  tags           = var.tags
}

resource "aws_secretsmanager_secret" "token" {
  #checkov:skip=CKV2_AWS_57: The api key stored as a secrets is passed down by the end user of this module, therefore secret rotation is not possible.
  name       = var.secret_name
  kms_key_id = var.kms_key_arn
  tags       = var.tags
}

resource "aws_secretsmanager_secret_version" "token" {
  secret_id     = aws_secretsmanager_secret.token.id
  secret_string = var.api_token
}

resource "aws_s3_object" "lambda_package" {
  bucket     = local.bucket_for_lambda_package.id
  key        = "${var.lambda_name}-lambda_function_${var.python_version}.zip"
  kms_key_id = var.kms_key_arn
  source     = var.lambda_pkg_path
  tags       = var.tags
}

module "lambda" {
  source  = "schubergphilis/mcaf-lambda/aws"
  version = "~> 1.4.1"

  name                   = var.lambda_name
  create_policy          = true
  create_s3_dummy_object = false
  description            = "Lambda to fetch audit logs from ${var.service_name} and store in S3"
  handler                = "main.handler"
  kms_key_arn            = var.kms_key_arn
  log_retention          = var.lambda_log_retention
  memory_size            = var.lambda_memory_size
  policy                 = data.aws_iam_policy_document.iam_policy.json
  runtime                = "python${var.python_version}"
  s3_bucket              = "${var.bucket_base_name}-lambda-${data.aws_caller_identity.current.account_id}"
  s3_key                 = aws_s3_object.lambda_package.key
  s3_object_version      = aws_s3_object.lambda_package.version_id
  source_code_hash       = aws_s3_object.lambda_package.checksum_sha256
  timeout                = 600
  tags                   = var.tags

  environment = merge({
    AUDIT_API_URL       = var.api_url
    BUCKET_NAME         = local.bucket_for_audit_logs.id
    BUCKET_PREFIX       = local.bucket_prefix
    COMPRESS_AUDIT_LOGS = var.compress_audit_logs
    DAYS_TO_FETCH       = var.days_to_fetch
    LOG_LEVEL           = var.lambda_log_level
    SECRET_NAME         = var.secret_name
  }, var.environment)

  depends_on = [
    local.bucket_for_lambda_package
  ]
}
