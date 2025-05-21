resource "aws_ecr_repository" "this" {
  name                 = var.name
  image_tag_mutability = "MUTABLE"
  tags                 = var.tags

  lifecycle {
    prevent_destroy = false
  }
}
