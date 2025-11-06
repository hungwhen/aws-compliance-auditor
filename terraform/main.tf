terraform {

  required_providers {

    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"
    }

  }

  required_version = ">=1.4.0"

}

provider "aws" {
  region = var.region
  // profile = var.aws_profile
}

//s3

resource "aws_s3_bucket" "config_logs" {

  bucket = "aws-config-logs-${var.account_id}-${var.region}"
  acl = "private"

  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Project = "aws-compliance-auditor"
  }

}

resource "aws_iam_role" "aws_config" {
  name = "aws-config-role-${var.account_id}-${var.region}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "aws_config" {
  name = "aws-config-policy"
  role = aws_iam_role.aws_config.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation", 
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.config_logs.arn,
          "${aws_s3_bucket.config_logs.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_config_configuration_recorder" "main" {
  name = "default"
  role_arn = aws_iam_role.aws_config.arn

  recording_group {
    all_supported = true
    include_global_resource_types = true
  }

}
