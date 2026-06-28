output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "API server endpoint for the EKS cluster"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded certificate authority data for the cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Cluster security group created by EKS"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "eks_admin_role_arn" {
  description = "ARN of the eks-admin role"
  value       = aws_iam_role.eks_admin.arn
}

output "eks_read_only_role_arn" {
  description = "ARN of the eks-read-only role"
  value       = aws_iam_role.eks_read_only.arn
}

output "node_role_arn" {
  description = "ARN of the worker node IAM role"
  value       = aws_iam_role.node.arn
}
