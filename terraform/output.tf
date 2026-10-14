output "sqs_queue_url" {
  value = aws_sqs_queue.orders_sqs.url
}

output "s3_bucket_name" {
  value = aws_s3_bucket.infraops-audit-logs.bucket
}

output "dynamo_table_name" {
  value = aws_dynamodb_table.orders_table.name
}
