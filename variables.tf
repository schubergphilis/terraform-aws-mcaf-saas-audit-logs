variable "bucket_base_name" {
  type        = string
  default     = "saas-audit-logs"
  description = "The base name for the S3 buckets"
}

variable "compress_audit_logs" {
  type        = bool
  default     = true
  description = "Whether to compress the audit logs before uploading to S3"
}

variable "create_bucket" {
  type        = bool
  default     = true
  description = "Whether to create the S3 bucket(s)"
}

variable "create_bucket_per_source" {
  type        = bool
  default     = false
  description = "Whether to create separate buckets per source"
}

variable "created_bucket_names" {
  type = object({
    audit_logs     = string
    lambda_package = string
  })
  default     = null
  description = "Names of existing S3 buckets to use"
}

variable "kms_key_arn" {
  type        = string
  description = "The ARN of the KMS key used to encrypt the resources"
}

variable "lambda_log_retention" {
  type        = number
  default     = 365
  description = "The number of days to retain the logs for the Lambda function"
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
  description = "Object locking configuration for S3 log and access-log buckets"
}

variable "scheduled_time" {
  type        = string
  default     = "09:00"
  description = "Time of day to trigger the audit Lambda functions (runs once a day)"
}

variable "sources" {
  type = map(object({
    api_token           = string
    api_url             = optional(string)
    bucket_prefix       = optional(string)
    compress_audit_logs = optional(bool)
    lambda_name         = optional(string)
    lambda_memory_size  = optional(number)
    lambda_log_level    = optional(string, "info")
    secret_name         = optional(string)
    tags                = optional(map(string))
  }))
  description = "Map of sources to fetch audit logs from"

  validation {
    condition     = length(keys(var.sources)) > 0
    error_message = "At least one source must be provided."
  }

  validation {
    condition     = alltrue([for source in keys(var.sources) : contains(["gitlab", "okta", "terraform-cloud"], source)])
    error_message = "Invalid key, supported sources: \"${join("\", \"", ["gitlab", "okta", "terraform-cloud"])}\"."
  }

  validation {
    condition     = alltrue([for source, config in var.sources : !(source == "okta" && config.api_url == null)])
    error_message = "When \"okta\" is specified as a source, the \"api_url\" value must be set."
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "A map of tags to assign to created resources"
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