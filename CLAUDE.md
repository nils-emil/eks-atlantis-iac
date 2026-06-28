# EKS Atlantis IAC

## Project Overview
Deploys an EKS cluster and Atlantis on AWS using Terraform and Helm.

## Stack
- Terraform (infrastructure)
- Helm (Atlantis deployment)
- AWS EKS, VPC
- GitHub (Atlantis webhook target)

## Structure
- `terraform/vpc/` — VPC, 2 subnets
- `terraform/eks/` — EKS cluster, autoscaling group, IAM roles
- `terraform/atlantis/` — Helm release for Atlantis

## Key conventions
- All infra is IaC, no manual steps
- Two IAM roles: `eks-admin`, `eks-read-only`
- Worker ASG: min 1, max 2

## Common commands
- `terraform init && terraform apply` in each module folder
- `helm upgrade --install atlantis ...`

## Git rules
- **NEVER push to git unless explicitly told to do so**
- Only commit or push when the user says "push" or "push to git"
- You may stage and commit locally, but do not run `git push` without permission
- 
## Security rules
- **NEVER commit secrets, keys, or credentials** to git
- Do not hardcode AWS access keys, secret keys, or tokens anywhere in code
- All secrets go in `.env` files or AWS Secrets Manager — never in `.tf` files
- Ensure `.gitignore` includes: `.env`, `*.tfvars`, `terraform.tfstate`, `.terraform/`
- If a secret is accidentally staged, stop and alert the user before doing anything
- IAM roles should follow least privilege principle
- Do not expose sensitive outputs in Terraform without marking them `sensitive = true`