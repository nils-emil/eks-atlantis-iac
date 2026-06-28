variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-north-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster (must match the value used in the vpc module)"
  type        = string
  default     = "atlantis-eks"
}

variable "kubernetes_version" {
  description = "Kubernetes control plane version (upgrade one minor at a time)"
  type        = string
  default     = "1.33"
}

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.small"
}

variable "node_ami_type" {
  description = "EKS-optimized AMI family for worker nodes (AL2 has no AMIs for Kubernetes 1.33+)"
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "node_min_size" {
  description = "Minimum number of worker nodes in the ASG"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes in the ASG"
  type        = number
  default     = 2
}

variable "node_desired_size" {
  description = "Desired number of worker nodes in the ASG"
  type        = number
  default     = 1
}

variable "state_bucket" {
  description = "S3 bucket holding the Terraform state for all modules"
  type        = string
}

variable "vpc_state_key" {
  description = "S3 key of the vpc module state within the state bucket"
  type        = string
  default     = "vpc/terraform.tfstate"
}
