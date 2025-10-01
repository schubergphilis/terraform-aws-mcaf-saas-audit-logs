locals {
  create_terraform_cloud_resources = contains(keys(var.sources), "terraform-cloud")
}

data "aws_iam_policy_document" "terraform_cloud" {
  count = local.create_terraform_cloud_resources ? 1 : 0

  statement {
    sid       = "AllowSQSToFrom"
    effect    = "Allow"
    resources = [aws_sqs_queue.terraform_cloud_audit_log[0].arn]

    actions = [
      "sqs:DeleteMessage",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage",
      "sqs:SendMessage",
      "sqs:GetQueueAttributes",
      "sqs:SendMessageBatch",
      "sqs:SetQueueAttributes"
    ]
  }
}

resource "aws_sqs_queue" "terraform_cloud_audit_log" {
  count = local.create_terraform_cloud_resources ? 1 : 0

  name                       = "terraform-audit-log"
  delay_seconds              = 90
  kms_master_key_id          = var.kms_key_arn
  max_message_size           = 2048
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 10
  visibility_timeout_seconds = 1200

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.terraform_cloud_audit_log_dlq[0].arn
    maxReceiveCount     = 4
  })
}

resource "aws_sqs_queue" "terraform_cloud_audit_log_dlq" {
  count = local.create_terraform_cloud_resources ? 1 : 0

  name                      = "terraform-audit-log-dlq"
  kms_master_key_id         = var.kms_key_arn
  message_retention_seconds = 691200
}

resource "aws_lambda_event_source_mapping" "terraform_audit_sqs_trigger" {
  count = local.create_terraform_cloud_resources ? 1 : 0

  batch_size       = 1
  event_source_arn = aws_sqs_queue.terraform_cloud_audit_log[0].arn
  function_name    = module.lambda["terraform-cloud"].arn
}

module "dlq_replay_lambda" {
  source  = "schubergphilis/mcaf-lambda/aws"
  version = "~> 1.4.1"

  name                        = "terraform-cloud-dlq-replay"
  create_policy               = true
  create_s3_dummy_object      = false
  description                 = "Lambda to replay messages from DLQ to main SQS queue for Terraform Cloud audit logs"
  handler                     = "dlq_replay.handler"
  kms_key_arn                 = var.kms_key_arn
  log_retention               = var.lambda_log_retention
  memory_size                 = 128
  policy                      = module.lambda["terraform-cloud"].iam_policy
  runtime                     = "python${var.python_version}"
  s3_bucket                   = "${var.bucket_base_name}-lambda-${data.aws_caller_identity.current.account_id}"
  s3_key                      = module.lambda["terraform-cloud"].s3_lambda_package_object_key
  s3_object_version           = module.lambda["terraform-cloud"].s3_lambda_package_object_version
  source_code_hash            = module.lambda["terraform-cloud"].s3_lambda_package_object_checksum_sha256
  subnet_ids                  = var.subnet_ids
  security_group_egress_rules = var.security_group_egress_rules
  tags                        = var.tags
  timeout                     = 600

  environment = {
    MAIN_QUEUE_URL = try(aws_sqs_queue.terraform_cloud_audit_log[0].id, "")
  }

  depends_on = [
    aws_sqs_queue.terraform_cloud_audit_log,
    aws_sqs_queue.terraform_cloud_audit_log_dlq,
    module.bucket_for_lambda_package,
  ]
}

resource "aws_lambda_permission" "allow_dlq_to_invoke_dlq_replay_lambda" {
  statement_id  = "AllowLambdaExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = module.dlq_replay_lambda.name
  principal     = "events.amazonaws.com"
  source_arn    = aws_sqs_queue.terraform_cloud_audit_log_dlq[0].arn
}
