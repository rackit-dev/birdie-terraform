terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.83"
    }
  }

  backend "s3" {
    bucket = "birdie-terraform-state-bucket"
    key    = "terraform/s3.tfstate"
    region = "ap-northeast-2"
  }
}

provider "aws" {
  region = local.region
}

################################################################################
# S3 Module
################################################################################

module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.6.0"

  bucket = "birdie-terraform-state-bucket"
  acl    = "private"

  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  versioning = {
    enabled = true
  }

  tags = {
    Terraform = "True"
  }
}