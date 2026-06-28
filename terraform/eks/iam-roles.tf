data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "eks_access_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_iam_role" "eks_admin" {
  name               = "eks-admin"
  assume_role_policy = data.aws_iam_policy_document.eks_access_assume.json
}

resource "aws_eks_access_entry" "eks_admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_iam_role.eks_admin.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "eks_admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_iam_role.eks_admin.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.eks_admin]
}

resource "aws_iam_role" "eks_read_only" {
  name               = "eks-read-only"
  assume_role_policy = data.aws_iam_policy_document.eks_access_assume.json
}

resource "aws_eks_access_entry" "eks_read_only" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_iam_role.eks_read_only.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "eks_read_only" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_iam_role.eks_read_only.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.eks_read_only]
}
