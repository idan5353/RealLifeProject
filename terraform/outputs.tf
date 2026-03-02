output "cluster_name" {
  value = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "rds_endpoint" {
  value = aws_db_instance.main.address
}

output "rds_secret_arn" {
  value = aws_secretsmanager_secret.db_password.arn
}

output "backend_ecr_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "frontend_ecr_url" {
  value = aws_ecr_repository.frontend.repository_url
}

output "backend_irsa_arn" {
  value = aws_iam_role.backend_sa.arn
}

output "assets_bucket" {
  value = aws_s3_bucket.assets.bucket
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}
