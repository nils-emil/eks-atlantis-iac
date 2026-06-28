data "terraform_remote_state" "eks" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    key    = var.eks_state_key
    region = var.region
  }
}

locals {
  cluster_name      = data.terraform_remote_state.eks.outputs.cluster_name
  cluster_endpoint  = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca        = data.terraform_remote_state.eks.outputs.cluster_ca_certificate
  oidc_provider_arn = data.terraform_remote_state.eks.outputs.oidc_provider_arn
  oidc_provider_url = data.terraform_remote_state.eks.outputs.oidc_provider_url
  service_account   = "atlantis"
}

data "aws_iam_policy_document" "atlantis_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(local.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${local.service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(local.oidc_provider_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "atlantis" {
  name               = "atlantis-irsa"
  assume_role_policy = data.aws_iam_policy_document.atlantis_assume.json
}

resource "aws_iam_role_policy_attachment" "atlantis_read_only" {
  role       = aws_iam_role.atlantis.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "atlantis_state" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
    ]
    resources = [
      "arn:aws:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/${var.lock_table}",
    ]
  }
}

resource "aws_iam_role_policy" "atlantis_state" {
  name   = "atlantis-state-lock"
  role   = aws_iam_role.atlantis.id
  policy = data.aws_iam_policy_document.atlantis_state.json
}

resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"

    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type = "gp3"
  }
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

      serviceAccount = {
        create = true
        name   = local.service_account
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.atlantis.arn
        }
      }

      environment = {
        AWS_REGION      = var.region
        TF_STATE_BUCKET = var.state_bucket
        TF_LOCK_TABLE   = var.lock_table
      }

      repoConfig = yamlencode({
        repos = [
          {
            id                     = "/.*/"
            allowed_overrides      = ["workflow"]
            allow_custom_workflows = true
          }
        ]
      })

      service = {
        type = "LoadBalancer"
        port = 80
      }
    })
  ]

  depends_on = [
    kubernetes_secret.github,
    kubernetes_storage_class_v1.gp3,
    aws_iam_role_policy_attachment.atlantis_read_only,
    aws_iam_role_policy.atlantis_state,
  ]
}
