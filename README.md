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
