terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.83"
    }
  }
}

data "aws_availability_zones" "available" {}

provider "aws" {
  region = local.region
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.19.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = ["10.0.1.0/24"]
  private_subnets = ["10.0.101.0/24"]

  public_subnet_tags = {
    Name = "Public-Subnet"
  }

  private_subnet_tags = {
    Name = "Private-Subnet"
  }

  public_route_table_tags = {
    Name = "Public-RTB"
  }

  private_route_table_tags = {
    Name = "Private-RTB"
  }

  nat_gateway_tags = {
    Name = "NAT"
  }

  igw_tags = {
    Name = "IGW"
  }

  enable_nat_gateway = true
  enable_vpn_gateway = false

  tags = {
    Terraform = "True"
  }
}