<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.32, < 7.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.32, < 7.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_bucket_for_access_logs"></a> [bucket\_for\_access\_logs](#module\_bucket\_for\_access\_logs) | schubergphilis/mcaf-s3/aws | ~> 0.14.1 |
| <a name="module_bucket_for_audit_logs"></a> [bucket\_for\_audit\_logs](#module\_bucket\_for\_audit\_logs) | schubergphilis/mcaf-s3/aws | ~> 0.14.1 |
| <a name="module_bucket_for_lambda_package"></a> [bucket\_for\_lambda\_package](#module\_bucket\_for\_lambda\_package) | schubergphilis/mcaf-s3/aws | ~> 0.14.1 |
| <a name="module_lambda"></a> [lambda](#module\_lambda) | schubergphilis/mcaf-lambda/aws | ~> 1.4.1 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_event_rule.trigger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.trigger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_lambda_permission.allow_cloudwatch_to_invoke_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_s3_object.lambda_package](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_secretsmanager_secret.token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.iam_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_s3_bucket.bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/s3_bucket) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_api_token"></a> [api\_token](#input\_api\_token) | Token used to authenticate to the audit API | `string` | n/a | yes |
| <a name="input_api_url"></a> [api\_url](#input\_api\_url) | Audit API endpoint | `string` | n/a | yes |
| <a name="input_bucket_base_name"></a> [bucket\_base\_name](#input\_bucket\_base\_name) | The base name for the S3 buckets | `string` | n/a | yes |
| <a name="input_bucket_prefix"></a> [bucket\_prefix](#input\_bucket\_prefix) | Prefix of objects created in the S3 bucket | `string` | n/a | yes |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | The ARN of the KMS key used to encrypt the resources | `string` | n/a | yes |
| <a name="input_lambda_name"></a> [lambda\_name](#input\_lambda\_name) | The name of the Lambda function | `string` | n/a | yes |
| <a name="input_lambda_pkg_path"></a> [lambda\_pkg\_path](#input\_lambda\_pkg\_path) | Path to the built Lambda function code to deploy | `string` | n/a | yes |
| <a name="input_secret_name"></a> [secret\_name](#input\_secret\_name) | The name of the Secrets Manager secret | `string` | n/a | yes |
| <a name="input_service_name"></a> [service\_name](#input\_service\_name) | The name of the service | `string` | n/a | yes |
| <a name="input_compress_audit_logs"></a> [compress\_audit\_logs](#input\_compress\_audit\_logs) | Whether to compress the audit logs before uploading to S3 | `bool` | `true` | no |
| <a name="input_create_bucket"></a> [create\_bucket](#input\_create\_bucket) | Whether to create S3 buckets | `bool` | `true` | no |
| <a name="input_created_bucket_names"></a> [created\_bucket\_names](#input\_created\_bucket\_names) | The names of existing S3 buckets to use | <pre>object({<br/>    audit_logs     = string<br/>    lambda_package = string<br/>  })</pre> | `null` | no |
| <a name="input_days_to_fetch"></a> [days\_to\_fetch](#input\_days\_to\_fetch) | The number of days of audit logs to fetch | `number` | `1` | no |
| <a name="input_dead_letter_queue"></a> [dead\_letter\_queue](#input\_dead\_letter\_queue) | The ARN of the dead letter queue for the CloudWatch event rule | `string` | `null` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Additional environment variables to pass to the Lambda function | `map(string)` | `null` | no |
| <a name="input_lambda_log_level"></a> [lambda\_log\_level](#input\_lambda\_log\_level) | The log level of the Lambda function | `string` | `"info"` | no |
| <a name="input_lambda_log_retention"></a> [lambda\_log\_retention](#input\_lambda\_log\_retention) | The number of days to retain the logs for the Lambda function | `number` | `365` | no |
| <a name="input_lambda_memory_size"></a> [lambda\_memory\_size](#input\_lambda\_memory\_size) | The amount of memory to allocate to the Lambda function | `number` | `256` | no |
| <a name="input_lambda_policy"></a> [lambda\_policy](#input\_lambda\_policy) | Additional policy statements to add to Lambda role | `string` | `null` | no |
| <a name="input_object_locking"></a> [object\_locking](#input\_object\_locking) | The object locking configuration for the S3 buckets | <pre>object({<br/>    mode  = optional(string, "GOVERNANCE")<br/>    years = optional(number, 1)<br/>  })</pre> | <pre>{<br/>  "mode": "GOVERNANCE",<br/>  "years": 1<br/>}</pre> | no |
| <a name="input_python_version"></a> [python\_version](#input\_python\_version) | The version of Python to use for the Lambda function | `string` | `"3.13"` | no |
| <a name="input_scheduled_time"></a> [scheduled\_time](#input\_scheduled\_time) | Time of day to run the Lambda function (runs once a day) | `string` | `"09:00"` | no |
| <a name="input_security_group_egress_rules"></a> [security\_group\_egress\_rules](#input\_security\_group\_egress\_rules) | Security Group egress rules | <pre>list(object({<br/>    cidr_ipv4                    = optional(string)<br/>    cidr_ipv6                    = optional(string)<br/>    description                  = string<br/>    from_port                    = optional(number, 0)<br/>    ip_protocol                  = optional(string, "-1")<br/>    prefix_list_id               = optional(string)<br/>    referenced_security_group_id = optional(string)<br/>    to_port                      = optional(number, 0)<br/>  }))</pre> | <pre>[<br/>  {<br/>    "cidr_ipv4": "0.0.0.0/0",<br/>    "description": "Default Security Group rule for SaaS Audit Lambda",<br/>    "ip_protocol": "tcp",<br/>    "to_port": 443<br/>  }<br/>]</pre> | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | The subnet ids where this lambda needs to run | `list(string)` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to assign to created resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arn"></a> [arn](#output\_arn) | The ARN of the Lambda function |
<!-- END_TF_DOCS -->
