resource "aws_ecr_repository" "app_repo" {
  name = local.app_name

  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  force_delete = true
}

data "aws_caller_identity" "current" {}



resource "local_file" "image_tag" {
  content    = local.image_tag
  filename   = "${path.module}/image_tag.txt"
}

