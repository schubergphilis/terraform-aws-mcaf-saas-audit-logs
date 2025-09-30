output "arn" {
  description = "The ARN of the Lambda function"
  value       = module.lambda.arn
}

output "s3_lambda_package_object_checksum_sha256" {
  description = "S3 Lambda package object checksum (sha256)"
  value       = aws_s3_object.lambda_package.checksum_sha256
}

output "s3_lambda_package_object_key" {
  description = "S3 Lambda package object key"
  value       = aws_s3_object.lambda_package.key
}

output "s3_lambda_package_object_version" {
  description = "S3 Lambda package object key"
  value       = aws_s3_object.lambda_package.version_id
}
