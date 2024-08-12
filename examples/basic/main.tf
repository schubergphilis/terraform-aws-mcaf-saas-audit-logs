provider "aws" {
  region = "eu-west-1"
}

module "kms" {
  source  = "schubergphilis/mcaf-kms/aws"
  version = "0.3.0"

  name = "example"
}

module "saas_audit_logs" {
  source = "../.."

  kms_key_arn = module.kms.arn

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