terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }
  }
}

resource "random_string" "account_id" {
  length      = 12
  min_numeric = 12
}

resource "random_string" "default" {
  length  = 4
  special = false
  upper   = false
}

resource "random_uuid" "default" {}

output "account_id" {
  value = random_string.account_id.id
}

output "random_string" {
  value = random_string.default.id
}

output "random_uuid" {
  value = random_uuid.default.result
}
