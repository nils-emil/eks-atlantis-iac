data "terraform_remote_state" "eks" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    key    = var.eks_state_key
    region = var.region
  }
}

locals {
  cluster_name     = data.terraform_remote_state.eks.outputs.cluster_name
  cluster_endpoint = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca       = data.terraform_remote_state.eks.outputs.cluster_ca_certificate
}

resource "kubernetes_namespace" "atlantis" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_secret" "github" {
  metadata {
    name      = "atlantis-github"
    namespace = kubernetes_namespace.atlantis.metadata[0].name
  }

  data = {
    "github_token"  = var.github_token
    "github_secret" = var.github_webhook_secret
  }

  type = "Opaque"
}

resource "helm_release" "atlantis" {
  name       = "atlantis"
  namespace  = kubernetes_namespace.atlantis.metadata[0].name
  repository = "https://runatlantis.github.io/helm-charts"
  chart      = "atlantis"
  version    = var.chart_version

  values = [
    yamlencode({
      image = {
        tag = var.atlantis_image_tag
      }

      orgAllowlist = var.repo_allowlist

      github = {
        user = var.github_user
      }

      vcsSecretName = kubernetes_secret.github.metadata[0].name

      service = {
        type = "LoadBalancer"
        port = 80
      }
    })
  ]

  depends_on = [kubernetes_secret.github]
}
