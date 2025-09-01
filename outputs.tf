output "ecr_repository_name" {
  description = "ECR repository name"
  value       = aws_ecr_repository.repo.name
}

output "ecr_repository_arn" {
  description = "ECR repository ARN"
  value       = aws_ecr_repository.repo.arn
}

output "ecr_repository_url" {
  description = "ECR repository URL for docker login/push"
  value       = aws_ecr_repository.repo.repository_url
}

output "eks_cluster_name" {
  value = module.eks_bottlerocket.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks_bottlerocket.cluster_endpoint
}

output "eks_node_group_role_arn" {
  value = module.eks_bottlerocket.eks_managed_node_groups["example"].iam_role_arn
}
