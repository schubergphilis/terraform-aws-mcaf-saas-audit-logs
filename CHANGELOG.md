# Changelog

All notable changes to this project will automatically be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v0.3.5 - 2025-10-01

### What's Changed

#### 🐛 Bug Fixes

* fix: Adding exponential backoff for Terraform rate limit errors with max retry (#11) @mayur7436

**Full Changelog**: https://github.com/schubergphilis/terraform-aws-mcaf-saas-audit-logs/compare/v0.3.4...v0.3.5

## v0.3.4 - 2025-09-15

### What's Changed

#### 🐛 Bug Fixes

* fix: Adding code to handle rate limit HTTP 429 errors from Terraform API (#10) @mayur7436

**Full Changelog**: https://github.com/schubergphilis/terraform-aws-mcaf-saas-audit-logs/compare/v0.3.3...v0.3.4

## v0.3.3 - 2025-09-05

### What's Changed

#### 🐛 Bug Fixes

* bug: Removing old packages before packaging (#9) @mayur7436

**Full Changelog**: https://github.com/schubergphilis/terraform-aws-mcaf-saas-audit-logs/compare/v0.3.2...v0.3.3

## v0.3.2 - 2025-09-05

### What's Changed

#### 🐛 Bug Fixes

* bug: Adding source_hash to trigger s3 object upload on code changes (#8) @mayur7436

**Full Changelog**: https://github.com/schubergphilis/terraform-aws-mcaf-saas-audit-logs/compare/v0.3.1...v0.3.2

## v0.3.1 - 2025-08-29

### What's Changed

#### 🐛 Bug Fixes

* security: Upgrading requests to fix CVE-2025-50182 and CVE-2024-47081 (#7) @mayur7436

**Full Changelog**: https://github.com/schubergphilis/terraform-aws-mcaf-saas-audit-logs/compare/v0.3.0...v0.3.1

## v0.3.0 - 2025-07-08

### What's Changed

#### 🚀 Features

feature: Support running audit Lambda inside a VPC (#6) @svashisht03

**Full Changelog**: https://github.com/schubergphilis/terraform-aws-mcaf-saas-audit-logs/compare/v0.2.1...v0.3.0

## v0.2.1 - 2025-06-24

### What's Changed

#### 🐛 Bug Fixes

* fix: allowing for aws provider version higher than 6 (#5) @macampo

**Full Changelog**: https://github.com/schubergphilis/terraform-aws-mcaf-saas-audit-logs/compare/v0.2.0...v0.2.1

## v0.2.0 - 2025-02-14

### What's Changed

#### 🚀 Features

* fix: Set the lambda runtime to 3.13 per default and updated the lambda libraries to latest versions. Python 3.12 is still supported, but not the default. In addition, added a workflow that will automatically build the lambda deployment packages and commit them to the repo (#4) @macampo

**Full Changelog**: https://github.com/schubergphilis/terraform-aws-mcaf-saas-audit-logs/compare/v0.1.1...v0.2.0

## v0.1.1 - 2024-08-14

### What's Changed

#### 🐛 Bug Fixes

* fix: Deploy lambdas using pre-built packages (#2) @shoekstra

**Full Changelog**: https://github.com/schubergphilis/terraform-aws-mcaf-saas-audit-logs/compare/v0.1.0...v0.1.1

## v0.1.0 - 2024-08-12

### What's Changed

#### 🚀 Features

* feat: First version (#1) @shoekstra

**Full Changelog**: https://github.com/schubergphilis/terraform-aws-mcaf-saas-audit-logs/releases/tag/v0.1.0
