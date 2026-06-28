# eks-atlantis-iac

Deploys an EKS cluster and Atlantis on AWS using Terraform and Helm.

## Architecture
- 1 VPC, 2 subnets
- 1 EKS cluster with autoscaling workers (min 1, max 2)
- IAM roles: `eks-admin` (admin), `eks-read-only` (read-only)
- Atlantis deployed via Helm, connected to this GitHub repo

## Prerequisites
- AWS CLI configured (`aws configure`)
- Terraform >= 1.0
- kubectl
- Helm >= 3.0
- GitHub personal access token

## Deploy

```bash
# 1. VPC
cd terraform/vpc
terraform init && terraform apply

# 2. EKS
cd ../eks
terraform init && terraform apply

# 3. Atlantis
cd ../atlantis
terraform init && terraform apply
```

## Verify Atlantis
Open a pull request in this repo — Atlantis should comment with a
`terraform plan` output automatically.

## Structure
```
terraform/
├── vpc/        # VPC and subnets
├── eks/        # EKS cluster, IAM roles, autoscaling
└── atlantis/   # Helm release for Atlantis
```