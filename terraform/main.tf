# Encrypted S3 Bucket for storing logs for Auditing
resource "aws_s3_bucket" "infraops-audit-logs" {
  bucket        = "${var.project_name}-audit-logs"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "infraops-audit-logs-bucket-versioning" {
  bucket = aws_s3_bucket.infraops-audit-logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "infraops-block-acl" {
  bucket                  = aws_s3_bucket.infraops-audit-logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# SQS Dead Letter Queue
resource "aws_sqs_queue" "orders_dlq" {
  name                      = "orders-dlq"
  message_retention_seconds = 86400
}

# SQS Queue for Order Items
resource "aws_sqs_queue" "orders_sqs" {
  name                       = "orders-sqs"
  visibility_timeout_seconds = 30
  redrive_allow_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.orders_dlq.arn
    maxReceiveCount     = 3
  })
}

# DynamoDB For Storing Metadata
resource "aws_dynamodb_table" "orders_table" {
  name         = "orders-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "order_id"

  attribute {
    name = "order_id"
    type = "S"
  }
}

# Least Priviledge IAM Service for API
data "aws_iam_policy_document" "api_least_privilege" {
  statement {
    sid       = "AllowSQSSendOnly"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.orders_sqs.arn]
  }

  statement {
    sid       = "AllowDynamoDBWriteOnly"
    effect    = "Allow"
    actions   = ["dynamodb:PutItem", "dynamodb:GetItem"]
    resources = [aws_dynamodb_table.orders_table.arn]
  }

}

resource "aws_iam_policy" "api_policy" {
  name   = "${var.project_name}-api-least-privilege"
  policy = data.aws_iam_policy_document.api_least_privilege.json
}
