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

module "bastion_ec2_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.3.0"
  
  name        = "bastion-ec2-sg"
  description = "Security Group for Bastion Host Instance"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress_with_cidr_blocks = [
    {
      rule        = "ssh-tcp"
      description = "SSH port"
      cidr_blocks = "0.0.0.0/0"
    },
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

module "fastapi_ec2_sg" {
  source = "terraform-aws-modules/security-group/aws"
  version = "5.3.0"

  name = "fastapi-ec2-sg"
  description = "Security Group for FastAPI Server Instance"
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress_with_cidr_blocks = [
    {
      rule        = "ssh-tcp"
      description = "SSH port"
      cidr_blocks = "${aws_eip.bastion_eip.private_ip}/32"
    },
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      description = "FastAPI port"
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

module "db_ec2_sg" {
  source = "terraform-aws-modules/security-group/aws"
  version = "5.3.0"

  name        = "db-ec2-sg"
  description = "Security Group for MySQL Server Instance"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress_with_cidr_blocks = [
    {
      rule        = "ssh-tcp"
      description = "SSH port"
      cidr_blocks = "${aws_eip.bastion_eip.private_ip}/32"
    },
    {
      rule        = "mysql-tcp"
      description = "MySQL port"
      cidr_blocks = "${aws_eip.fastapi_eip.private_ip}/32"
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

resource "aws_eip" "bastion_eip" {
  domain   = "vpc"
  instance = module.ec2_instance_bastion.id

  tags = {
    Name      = "bastion-eip"
    Terraform = "True"
  }
}

resource "aws_eip" "fastapi_eip" {
  domain   = "vpc"
  instance = module.ec2_instance_fastapi.id

  tags = {
    Name      = "fastapi-eip"
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

  instance_type          = "t3.micro"
  ami                    = local.ami
  key_name               = local.key_name
  monitoring             = true
  vpc_security_group_ids = [module.bastion_ec2_sg.security_group_id]
  subnet_id              = data.terraform_remote_state.vpc.outputs.public_subnets[0]

  tags = {
    Terraform = "True"
  }
}

module "ec2_instance_fastapi" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.7.1"

  name = "birdie-fastapi-host"

  instance_type          = "t3.medium"
  ami                    = local.ami
  key_name               = local.key_name
  monitoring             = true
  vpc_security_group_ids = [module.fastapi_ec2_sg.security_group_id]
  subnet_id              = data.terraform_remote_state.vpc.outputs.public_subnets[0]

  root_block_device = [
    {
      volume_size           = 20
      volume_type           = "gp3"
      delete_on_termination = true
    }
  ]

  tags = {
    Terraform = "True"
  }
}

module "ec2_instance_db" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.7.1"

  name = "birdie-db"

  instance_type          = "t3.small"
  ami                    = local.ami
  key_name               = local.key_name
  monitoring             = true
  vpc_security_group_ids = [module.db_ec2_sg.security_group_id]
  subnet_id              = data.terraform_remote_state.vpc.outputs.private_subnets[0]

  root_block_device = [
    {
      volume_size           = 20
      volume_type           = "gp3"
      delete_on_termination = true
    }
  ]

  tags = {
    DB_Engine = "MySQL"
    Terraform = "True"
  }
}