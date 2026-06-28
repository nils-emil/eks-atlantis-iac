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

## Deployment
- Everything runs in GitHub Actions — no local Terraform/Helm/kubectl needed
- `terraform.yml`: plan on PR, apply on merge to `main` (`vpc` → `eks` → `atlantis`)
- `bootstrap-backend.yml`: one-time S3 + DynamoDB remote-state setup (run manually)
- Helm is applied by the `atlantis` Terraform module (`helm_release`), not by hand
- Config via Actions Variables; secrets via Actions Secrets; passed to Terraform as `TF_VAR_*`

## Git rules
- **NEVER push to git unless explicitly told to do so**
- Only commit or push when the user says "push" or "push to git"
- You may stage and commit locally, but do not run `git push` without permission
- 
## Security rules
- **NEVER commit secrets, keys, or credentials** to git
- Do not hardcode AWS access keys, secret keys, or tokens anywhere in code
- All secrets go in GitHub Actions Secrets or AWS Secrets Manager — never in `.tf`/`.tfvars` files
- Ensure `.gitignore` includes: `.env`, `*.tfvars`, `terraform.tfstate`, `.terraform/`
- If a secret is accidentally staged, stop and alert the user before doing anything
- IAM roles should follow least privilege principle
- Do not expose sensitive outputs in Terraform without marking them `sensitive = true`