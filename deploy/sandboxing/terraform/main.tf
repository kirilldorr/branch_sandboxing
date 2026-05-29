terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket       = "terraform-sandbox-blogpost"
    key          = "k3s-autoscaling-workers/terraform.tfstate"
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

resource "aws_launch_template" "worker" {
  name_prefix   = "k3s-worker-lt-"
  image_id      = data.aws_ami.ubuntu_22_04.id
  instance_type = var.instance_type
  key_name      = data.terraform_remote_state.base.outputs.key_name

  iam_instance_profile {
    name = data.terraform_remote_state.base.outputs.iam_instance_profile
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [data.terraform_remote_state.base.outputs.security_group_id]
  }

  instance_market_options {
    market_type = "spot"
  }

  user_data = base64encode(<<-EOF
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

    echo 'systemctl restart k3s-agent || true' >> /usr/local/bin/update-ecr-token.sh
    chmod +x /usr/local/bin/update-ecr-token.sh
    /usr/local/bin/update-ecr-token.sh
    
    echo "0 */10 * * * root /usr/local/bin/update-ecr-token.sh > /var/log/ecr-cron.log 2>&1" > /etc/cron.d/update-ecr-token
    
    EC2_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
    INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $EC2_TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)
    AZ=$(curl -H "X-aws-ec2-metadata-token: $EC2_TOKEN" -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${var.k3s_version}" K3S_URL="https://${data.terraform_remote_state.base.outputs.public_ip}:6443" K3S_TOKEN="${var.k3s_token}" sh -s - agent --kubelet-arg="provider-id=aws:///$AZ/$INSTANCE_ID"
  EOF
  )

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = 10
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "workers" {
  name                = "k3s-workers-asg"
  min_size            = 0
  max_size            = 10
  desired_capacity    = 0
  vpc_zone_identifier = [data.terraform_remote_state.base.outputs.subnet_id]

  launch_template {
    id      = aws_launch_template.worker.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "k3s-autoscaling-worker"
    propagate_at_launch = true
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    value               = "true"
    propagate_at_launch = true
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/my-sandbox-cluster"
    value               = "owned"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}
