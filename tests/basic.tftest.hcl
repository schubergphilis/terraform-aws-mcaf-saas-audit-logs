mock_provider "aws" {}

run "setup" {
  module {
    source = "./tests/setup"
  }
}

run "basic" {
  command = plan

  variables {
    kms_key_arn = "arn:aws:kms:eu-central-1:${run.setup.account_id}:key/${run.setup.random_uuid}"
    sources     = {}
  }

  expect_failures = [
    var.sources,
  ]
}
