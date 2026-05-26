output "app_endpoint" {
  value = "http://${aws_instance.ec2_instance.public_dns}"
}

output "ssh_connect_command" {
  value = "ssh -i .keys/id_rsa ubuntu@${aws_instance.ec2_instance.public_dns}"
}

output "hash" {
  value = local.image_tag
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app_repo.repository_url
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  value = local.aws_region
}

output "public_ip" {
  value = aws_instance.ec2_instance.public_ip
}

output "subnet_id" {
  value = aws_subnet.public_a.id
}

output "security_group_id" {
  value = aws_security_group.app_sg.id
}

output "iam_instance_profile" {
  value = aws_iam_instance_profile.instance_profile.name
}

output "key_name" {
  value = aws_key_pair.app_deployer.key_name
}

output "instance_type" {
  value = aws_instance.ec2_instance.instance_type
}
