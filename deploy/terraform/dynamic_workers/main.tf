terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket       = "terraform-sandbox-blogpost"
    use_lockfile = true
    region       = "us-west-2"
  }
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
  region = data.terraform_remote_state.base.outputs.aws_region
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
    apt-get update
    apt-get install -y awscli

    echo '#!/bin/bash' > /usr/local/bin/update-ecr-token.sh
    echo 'TOKEN=$(aws ecr get-login-password --region ${data.terraform_remote_state.base.outputs.aws_region})' >> /usr/local/bin/update-ecr-token.sh
    echo 'mkdir -p /etc/rancher/k3s' >> /usr/local/bin/update-ecr-token.sh
    echo 'cat <<YAML > /etc/rancher/k3s/registries.yaml' >> /usr/local/bin/update-ecr-token.sh
    echo 'configs:' >> /usr/local/bin/update-ecr-token.sh
    echo '  "${data.terraform_remote_state.base.outputs.account_id}.dkr.ecr.${data.terraform_remote_state.base.outputs.aws_region}.amazonaws.com":' >> /usr/local/bin/update-ecr-token.sh
    echo '    auth:' >> /usr/local/bin/update-ecr-token.sh
    echo '      username: AWS' >> /usr/local/bin/update-ecr-token.sh
    echo '      password: "$TOKEN"' >> /usr/local/bin/update-ecr-token.sh
    echo 'YAML' >> /usr/local/bin/update-ecr-token.sh
    
    echo 'systemctl restart k3s-agent' >> /usr/local/bin/update-ecr-token.sh
    chmod +x /usr/local/bin/update-ecr-token.sh
    /usr/local/bin/update-ecr-token.sh
    echo "0 */10 * * * root /usr/local/bin/update-ecr-token.sh > /var/log/ecr-cron.log 2>&1" > /etc/cron.d/update-ecr-token
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${var.k3s_version}" K3S_URL="https://${data.terraform_remote_state.base.outputs.public_ip}:6443" K3S_TOKEN="${var.k3s_token}" sh -
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
