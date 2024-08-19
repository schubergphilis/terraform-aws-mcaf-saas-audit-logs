variable "api_token" {
  type        = string
  description = "Token used to authenticate to the audit API"
}

variable "api_url" {
  type        = string
  description = "Audit API endpoint"
}

variable "bucket_base_name" {
  type        = string
  description = "The base name for the S3 buckets"
}

variable "bucket_prefix" {
  type        = string
  description = "Prefix of objects created in the S3 bucket"
}

variable "create_bucket" {
  type        = bool
  default     = true
  description = "Whether to create S3 buckets"

  validation {
    condition     = var.create_bucket || var.created_bucket_names != {}
    error_message = "Either create_bucket or bucket_arns must be set."
  }
}

variable "created_bucket_names" {
  type = object({
    audit_logs     = string
    lambda_package = string
  })
  default     = null
  description = "The names of existing S3 buckets to use"
}

variable "dead_letter_queue" {
  type        = string
  default     = null
  description = "The ARN of the dead letter queue for the CloudWatch event rule"
}

variable "compress_audit_logs" {
  type        = bool
  default     = true
  description = "Whether to compress the audit logs before uploading to S3"
}

variable "days_to_fetch" {
  type        = number
  default     = 1
  description = "The number of days of audit logs to fetch"
}

variable "environment" {
  type        = map(string)
  default     = null
  description = "Additional environment variables to pass to the Lambda function"
}

variable "kms_key_arn" {
  type        = string
  description = "The ARN of the KMS key used to encrypt the resources"
}

variable "lambda_log_level" {
  type        = string
  default     = "info"
  description = "The log level of the Lambda function"
}

variable "lambda_log_retention" {
  type        = number
  default     = 365
  description = "The number of days to retain the logs for the Lambda function"
}

variable "lambda_memory_size" {
  type        = number
  default     = 256
  description = "The amount of memory to allocate to the Lambda function"
  nullable    = false
}

variable "lambda_name" {
  type        = string
  description = "The name of the Lambda function"
}

variable "lambda_pkg_path" {
  type        = string
  description = "Path to the built Lambda function code to deploy"
}

variable "lambda_policy" {
  type        = string
  description = "Additional policy statements to add to Lambda role"
  default     = null
}

variable "object_locking" {
  type = object({
    mode  = optional(string, "GOVERNANCE")
    years = optional(number, 1)
  })
  default = {
    mode  = "GOVERNANCE"
    years = 1
  }
  description = "The object locking configuration for the S3 buckets"
}

variable "python_version" {
  type        = string
  default     = "3.12"
  description = "The version of Python to use for the Lambda function"
  validation {
    condition = contains(["3.8", "3.9", "3.10", "3.11", "3.12"], var.python_version)
    error_message = "The python_version must be one of: 3.8, 3.9, 3.10, 3.11, 3.12."
  }
}

variable "scheduled_time" {
  type        = string
  default     = "09:00"
  description = "Time of day to run the Lambda function (runs once a day)"
}

variable "secret_name" {
  type        = string
  description = "The name of the Secrets Manager secret"
}

variable "service_name" {
  type        = string
  description = "The name of the service"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "A map of tags to assign to created resources"
}
