# terraform-aws-mcaf-saas-audit-logs

Terraform module to fetch audit logs from SaaS providers.

This module will create the necessary resources to fetch audit logs from SaaS providers and store them in an S3 bucket. Currently these providers are supported:

- GitLab
- Okta
- Terraform Cloud

> [!NOTE]
> This module was created as a way to store audit logs in a central location for compliance purposes. At this time the lambdas collect logs for the previous day and can only be scheduled once per day. In a future version we will add log deduplication and the ability to fetch logs more frequently.

## Usage

The module requires at least `var.kms_key_arn` and one source configured in `var.sources`. Below shows the most minimal configuration for each source:

```hcl
module "saas_audit_logs" {
  source = "schubergphilis/mcaf-saas-audit-logs/aws"

  kms_key_arn = module.kms_key.arn

  sources = {
    gitlab = {
      api_token = var.gitlab_api_token
    }

    okta = {
      api_token = var.okta_api_token
      api_url   = "https://yourorg.okta.com"
    }

    terraform-cloud = {
      api_token = var.terraform_api_token
    }
  }
}
```

With this configuration the module will

- Create 3 buckets:
  - A bucket for audit logs
  - A bucket for the audit logs access logs
  - A bucket for the lambda packages
- Deploy a lambda per source to fetch the logs and store in the audit log bucket, using the provider name as a bucket prefix
- Schedule the lambdas to run at 9am UTC every day

Optionally you can create a bucket per source, by setting `var.create_bucket_per_source` to true, or bring your own bucket by populating the `var.created_bucket_names`:

```hcl
created_bucket_names = {
  audit_logs     = "your-audit-logs-bucket"
  lambda_package = "your-lambda-packages-bucket"
  }
}
```

### Tuning

Each source can be tuned by setting the following optional fields:

| field                 | description                                                                                       |
| --------------------- | ------------------------------------------------------------------------------------------------- |
| `bucket_prefix`       | Set a custom prefix for the stored logs for this source (defaults to source name)                 |
| `compress_audit_logs` | Store logs as compressed files (defaults to `true`)                                               |
| `lambda_name`         | Set a custom name for the lambda function                                                         |
| `lambda_memory_size`  | Set the memory size for the lambda function (defaults to `256`)                                   |
| `lambda_log_level`    | Set the log level for the lambda function (defaults to `INFO`)                                    |
| `secret_name`         | Set a custom secret name for the lambda function (defaults to `/audit-log-tokens/${source_name)`) |
| `tags`                | Any additional tags to apply to the created resources                                             |

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
| <a name="module_lambda"></a> [lambda](#module\_lambda) | ./modules/audit-lambda | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_lambda_event_source_mapping.terraform_audit_sqs_trigger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_event_source_mapping) | resource |
| [aws_sqs_queue.terraform_cloud_audit_log](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.terraform_cloud_audit_log_dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.terraform_cloud](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | The ARN of the KMS key used to encrypt the resources | `string` | n/a | yes |
| <a name="input_sources"></a> [sources](#input\_sources) | Map of sources to fetch audit logs from | <pre>map(object({<br/>    api_token           = string<br/>    api_url             = optional(string)<br/>    bucket_prefix       = optional(string)<br/>    compress_audit_logs = optional(bool)<br/>    lambda_name         = optional(string)<br/>    lambda_memory_size  = optional(number)<br/>    lambda_log_level    = optional(string, "info")<br/>    secret_name         = optional(string)<br/>    tags                = optional(map(string))<br/>  }))</pre> | n/a | yes |
| <a name="input_bucket_base_name"></a> [bucket\_base\_name](#input\_bucket\_base\_name) | The base name for the S3 buckets | `string` | `"saas-audit-logs"` | no |
| <a name="input_compress_audit_logs"></a> [compress\_audit\_logs](#input\_compress\_audit\_logs) | Whether to compress the audit logs before uploading to S3 | `bool` | `true` | no |
| <a name="input_create_bucket"></a> [create\_bucket](#input\_create\_bucket) | Whether to create the S3 bucket(s) | `bool` | `true` | no |
| <a name="input_create_bucket_per_source"></a> [create\_bucket\_per\_source](#input\_create\_bucket\_per\_source) | Whether to create separate buckets per source | `bool` | `false` | no |
| <a name="input_created_bucket_names"></a> [created\_bucket\_names](#input\_created\_bucket\_names) | Names of existing S3 buckets to use | <pre>object({<br/>    audit_logs     = string<br/>    lambda_package = string<br/>  })</pre> | `null` | no |
| <a name="input_lambda_log_retention"></a> [lambda\_log\_retention](#input\_lambda\_log\_retention) | The number of days to retain the logs for the Lambda function | `number` | `365` | no |
| <a name="input_object_locking"></a> [object\_locking](#input\_object\_locking) | Object locking configuration for S3 log and access-log buckets | <pre>object({<br/>    mode  = optional(string, "GOVERNANCE")<br/>    years = optional(number, 1)<br/>  })</pre> | <pre>{<br/>  "mode": "GOVERNANCE",<br/>  "years": 1<br/>}</pre> | no |
| <a name="input_python_version"></a> [python\_version](#input\_python\_version) | The version of Python to use for the Lambda function | `string` | `"3.13"` | no |
| <a name="input_scheduled_time"></a> [scheduled\_time](#input\_scheduled\_time) | Time of day to trigger the audit Lambda functions (runs once a day) | `string` | `"09:00"` | no |
| <a name="security_grpup_egress_rules"></a> [security\_group\_egress_rules](#input\_security\_group\_egress_rules) | Security Group egress rules        | `list`    | `[]`  | no |
| <a name="subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids)| Subnet ids where lambda is run     | `list(string)` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to assign to created resources | `map(string)` | `{}` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->

## License

**Copyright:** Schuberg Philis

```text
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
