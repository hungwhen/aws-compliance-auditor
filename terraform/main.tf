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

resource "aws_iam_role_policy_attachment" "aws_config_managed" {
    role = aws_iam_role.aws_config.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRole"
}

resource "aws_s3_bucket_policy" "config_logs" {

    bucket = aws_s3_bucket.config_logs.id

    policy = jsonencode({
    
        Version = "2012-10-17"
        Statement = [
            {
                Sid = "AWSConfigBucketPermissionsCheck"
                Effect = "Allow"
                Principal = {
                    Service = "config.amazonaws.com"
                }
                Action = "s3:GetBucketAcl"
                Resource = aws_s3_bucket.config_logs.arn
            },
            {
                Sid = "AWSConfigBucketDelivery"
                Effect = "Allow"
                Principal = {
                    Service = "config.amazonaws.com"
                }
                Action = "s3:PutObject"
                Resource = "${aws_s3_bucket.config_logs.arn}/*"
                Condition = {
                    StringEquals = {
                        "s3:x-amz-acl" = "bucket-owner-full-control"
                    }
                }
            }
        ]
    })
}

resource "aws_config_delivery_channel" "main" {
    
    name = "default"
    s3_bucket_name = aws_s3_bucket.config_logs.bucket    

    sns_topic_arn = aws_sns_topic.compliance_alerts.arn

    depends_on = [aws_config_configuration_recorder.main]

}

resource "aws_config_configuration_recorder_status" "main" {
    
    name = aws_config_configuration_recorder.main.name
    is_enabled = true

    depends_on = [aws_config_delivery_channel.main]

}

#misconfigs

resource "aws_config_config_rule" "s3_public_read_prohibited" {
    name = "s3-bucket-public-read-prohibited"
    source {
        owner = "AWS"
        source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
    }
    tags = {
        Frameworks = "CIS-1.2.0, NIST-AC-3, ISO-27001-A.9.1"
    }
}

resource "aws_config_config_rule" "s3_public_write_prohibited" {

    name = "s3-bucket-public-write-prohibited"
    source {
        owner = "AWS"
        source_identifier  = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
    }
    tags = {
        Frameworks = "CIS-1.2.0, NIST-SC-7, ISO-27001-A.13.1"
    }
}

resource "aws_config_config_rule" "restricted_ssh" {

    name = "restricted-ssh"

    source {
        owner = "AWS"
        source_identifier = "INCOMING_SSH_DISABLED"
    }

    tags = {
        Frameworks = "CIS-4.1, NIS-AC-4, ISO-27001-A.13.1"
    }
}

resource "aws_config_config_rule" "iam_access_keys_rotated" {
    name = "iam-access-keys-rotated"
    source {
        owner = "AWS"
        source_identifier = "ACCESS_KEYS_ROTATED"
    }
    input_parameters = jsonencode({
        maxAccessKeyAge = "90" # this is in days
    })
    tags = {
        Frameworks = "CIS-1.4,NIST-IA-5,ISO-27001-A.9.2"
    }
}

resource "aws_sns_topic" "compliance_alerts" {
    name = "compliance-alerts"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Sid = "AllowAWSConfigToPublish"
                Effect = "Allow"
                Principal = {
                    Service = "config.amazonaws.com"
                }
                Action = "sns:Publish"
                Resource = aws_sns_topic.compliance_alerts.arn
            } 
        ]
    })
}

resource "aws_sns_topic_subscription" "compliance_email" {
    topic_arn = aws_sns_topic.compliance_alerts.arn
    protocol = "email"
    endpoint = var.alert_email
}

resource "aws_s3_bucket_versioning" "config_logs" {
    bucket = aws_s3_bucket.config_logs.id
    versioning_configuration {
        status = "Enabled"
    }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config_logs" {
    bucket = aws_s3_bucket.config_logs.id
    rule {
        apply_server_side_encryption_by_default {
            sse_algorithm =  "aws:kms"
        }
    }
}

resource "aws_s3_bucket_public_access_block" "config_logs" {

    bucket = aws_s3_bucket.config_logs.id
    block_public_acls = true
    block_public_policy = true
    ignore_public_acls = true
    restrict_public_buckets = true

}


