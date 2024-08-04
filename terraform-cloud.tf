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
