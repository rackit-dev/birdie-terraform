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
    key    = "terraform/ec2.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = local.state_bucket
    key    = "terraform/vpc.tfstate"
    region = local.region
  }
}

provider "aws" {
  region = local.region
}

################################################################################
# Security Group Module
################################################################################

module "web_server_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.3.0"
  
  name        = "web-server-sg"
  description = "Security Group for Webserver Instance"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      description = "FastAPI port"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      rule       = "ssh-tcp"
      description = "SSH port"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      rule        = "mysql-tcp"
      description = "MySQL port"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      rule        = "https-443-tcp"
      description = "Https port"
      cidr_blocks = "0.0.0.0/0"
    }
  ]  
  
  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  tags = {
    Terraform = "True"
  }
}

################################################################################
# Elastic IPs
################################################################################

resource "aws_eip" "web_eip" {
  domain   = "vpc"
  instance = module.ec2_instance_bastion.id  # 생성한 EC2 인스턴스에 EIP 할당

  tags = {
    Name      = "bastion-eip"
    Terraform = "True"
  }
}

################################################################################
# EC2 Module
################################################################################

module "ec2_instance_bastion" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.7.1"

  name = "birdie-bastion-host"

  instance_type          = "t2.micro"
  ami                    = "ami-024ea438ab0376a47"
  key_name               = "birdie-key"
  monitoring             = true
  vpc_security_group_ids = [module.web_server_sg.security_group_id]
  subnet_id              = data.terraform_remote_state.vpc.outputs.public_subnets[0]

  tags = {
    Terraform = "True"
  }
}