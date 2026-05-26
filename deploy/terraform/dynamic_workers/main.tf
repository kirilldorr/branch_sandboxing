terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {}
}

data "terraform_remote_state" "base" {
  backend = "s3"
  config = {
    bucket = "terraform-sandbox-blogpost"
    key    = "terraform.tfstate"
    region = "us-west-2"
  }
}

provider "aws" {
  region  = data.terraform_remote_state.base.outputs.aws_region
  profile = "myaws"
}

data "aws_ami" "ubuntu_22_04" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "worker" {
  instance_type = var.instance_type
  ami           = data.aws_ami.ubuntu_22_04.id

  iam_instance_profile        = data.terraform_remote_state.base.outputs.iam_instance_profile
  subnet_id                   = data.terraform_remote_state.base.outputs.subnet_id
  vpc_security_group_ids      = [data.terraform_remote_state.base.outputs.security_group_id]
  associate_public_ip_address = true
  key_name                    = data.terraform_remote_state.base.outputs.key_name

  tags = {
    Name = "sandbox-worker-${var.branch_slug}"
  }

  user_data = <<-EOF
    #!/bin/bash
    set -e
    curl -sfL https://get.k3s.io | K3S_URL="https://${data.terraform_remote_state.base.outputs.public_ip}:6443" K3S_TOKEN="${var.k3s_token}" sh -
    EOF

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [ami]
  }

  root_block_device {
    volume_size           = 10
    volume_type           = "gp2"
    delete_on_termination = true
  }
}
