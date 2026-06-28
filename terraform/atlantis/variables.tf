variable "region" {
  description = "AWS region the cluster lives in"
  type        = string
  default     = "eu-north-1"
}

variable "state_bucket" {
  description = "S3 bucket holding the Terraform state for all modules"
  type        = string
}

variable "eks_state_key" {
  description = "S3 key of the eks module state within the state bucket"
  type        = string
  default     = "eks/terraform.tfstate"
}

variable "namespace" {
  description = "Kubernetes namespace to deploy Atlantis into"
  type        = string
  default     = "atlantis"
}

variable "chart_version" {
  description = "Version of the runatlantis Helm chart"
  type        = string
  default     = "6.7.1"
}

variable "atlantis_image_tag" {
  description = "Atlantis container image tag"
  type        = string
  default     = "v0.44.1"
}

variable "github_user" {
  description = "GitHub username the Atlantis token belongs to"
  type        = string
}

variable "github_token" {
  description = "GitHub personal access token for Atlantis"
  type        = string
  sensitive   = true
}

variable "github_webhook_secret" {
  description = "Shared secret used to validate incoming GitHub webhooks"
  type        = string
  sensitive   = true
}

variable "repo_allowlist" {
  description = "Atlantis repo allowlist (e.g. github.com/myorg/eks-atlantis-iac)"
  type        = string
}
