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
