# eks-atlantis-iac

Deploys an EKS cluster and Atlantis on AWS using Terraform and Helm.

## Possible improvements

Deliberate trade-offs for a lean setup; production hardening would add:

- **GitHub OIDC for AWS auth** — replace the long-lived `AWS_ACCESS_KEY_ID` /
  `AWS_SECRET_ACCESS_KEY` secrets with OIDC role federation, so Actions assumes
  a role with short-lived credentials and there are no static keys to rotate.
- **HTTPS for Atlantis** — terminate TLS at the load balancer with an ACM cert
  and a real domain (Route 53). The webhook endpoint is plain HTTP today.
- **Private node subnets + NAT** — run workers in private subnets and keep only
  the load balancer public; both subnets are public today.
- **Drop DynamoDB, use S3-native locking** (`use_lockfile`, Terraform ≥ 1.11) —
  removes the lock table, its IAM permissions, and the deprecation warning.
- **Least-privilege IAM** — scope the CI role to the services used (not
  `AdministratorAccess`), and narrow the `eks-admin`/`eks-read-only` trust from
  the whole account to specific principals.

## The role of Atlantis here (and why it's plan-only)

This repository bootstraps the cluster Atlantis runs on, so Atlantis shouldn't
own applies for it: something has to apply the cluster before Atlantis even
exists (bootstrap ordering), and letting Atlantis apply `eks` would roll the very
nodes it runs on (self-management hazard). So by design it's plan-only with a
read-only role: Atlantis posts `terraform plan` on PRs and GitHub Actions applies
on merge.

Where Atlantis actually earns its keep is owning the full plan→apply loop
(`atlantis apply`, with locking and approvals) for downstream workload repos that
run on the cluster. This bootstrap repo stays on the Actions-applies model, and
Atlantis manages those separate repos instead.

## Architecture
- 1 VPC, 2 subnets
- 1 EKS cluster with autoscaling workers (min 1, max 2)
- IAM roles: `eks-admin` (admin), `eks-read-only` (read-only)
- EBS CSI driver + default `gp3` StorageClass for Atlantis's persistent volume
- Atlantis deployed via Helm, connected to this GitHub repo (plan-only, IRSA role)

## How it works

Everything runs in GitHub Actions — there is nothing to install locally.

- **`terraform.yml`** — on a pull request it runs `terraform fmt`/`validate`
  checks; on merge to `main` it runs `terraform apply`. Modules run in order:
  `vpc` → `eks` → `atlantis`.
- **`terraform-module.yml`** — reusable workflow that does init/validate/apply
  for a single module.
- **`bootstrap-backend.yml`** — one-time, manually-triggered workflow that
  creates the S3 bucket + DynamoDB table used for remote Terraform state and
  locking.

State lives in S3 (not on a laptop), so the pipeline is fully stateless.

**Plan vs apply split.** Atlantis runs `terraform plan` on pull requests (driven
by `atlantis.yaml`) and uses a read-only AWS role, so it never mutates infra.
GitHub Actions performs the `apply` on merge to `main`. This keeps two appliers
from racing on the same state, and stops Atlantis from modifying the very
cluster it runs on.

## Prerequisites
- An AWS account
- This repository hosted on GitHub
- A GitHub personal access token for Atlantis

> For the handful of read-only checks after deploy (e.g. fetching the Atlantis
> URL), use AWS CloudShell — a browser terminal with the AWS CLI and
> `kubectl` preinstalled. No local installs required.

## Setup guide

### 1. AWS account and IAM user (browser)

1. **Create / use an AWS account** at https://aws.amazon.com.
2. **Create an IAM user for CI** (Console → IAM → Users → Create user). Do *not*
   use the account root user.
3. **Grant permissions.** This project creates VPC, EKS, EC2, IAM, S3, and
   DynamoDB resources. For a sandbox account, attach the AWS-managed
   `AdministratorAccess` policy. For a shared account, scope a custom policy to
   the services used here (`ec2:*`, `eks:*`, `iam:*`, `autoscaling:*`,
   `s3:*`, `dynamodb:*`).
4. **Create an access key** (the user → Security credentials → Create access
   key → "Application running outside AWS"). Copy both values.

### 2. GitHub token and webhook secret

1. **Personal access token** — GitHub → Settings → Developer settings →
   Personal access tokens → *Tokens (classic)* → Generate new token. Grant the
   `repo` scope. Copy the token (`ghp_…`); you'll only see it once.
2. **Webhook secret** — any random string Atlantis uses to verify webhooks.
   Generate one in AWS CloudShell with `openssl rand -hex 20`, or use a
   password manager.

### 3. Configure GitHub Actions secrets and variables

In the repo → **Settings → Secrets and variables → Actions**.

**Secrets** (encrypted):

| Name | Value |
|------|-------|
| `AWS_ACCESS_KEY_ID` | from step 1.4 |
| `AWS_SECRET_ACCESS_KEY` | from step 1.4 |
| `ATLANTIS_GITHUB_TOKEN` | the `ghp_…` token from step 2.1 |
| `ATLANTIS_GITHUB_WEBHOOK_SECRET` | the random string from step 2.2 |

**Variables** (plaintext):

| Name | Example |
|------|---------|
| `AWS_REGION` | `eu-north-1` |
| `TF_STATE_BUCKET` | `eks-atlantis-tfstate-<your-account-id>` (must be globally unique) |
| `TF_LOCK_TABLE` | `eks-atlantis-tf-locks` |
| `ATLANTIS_GITHUB_USER` | your GitHub username |
| `ATLANTIS_REPO_ALLOWLIST` | `github.com/your-org/eks-atlantis-iac` |

### 4. Bootstrap the state backend (one time)

Actions tab → **bootstrap-backend** → **Run workflow**. This creates the S3
bucket and DynamoDB lock table named by `TF_STATE_BUCKET` / `TF_LOCK_TABLE`.
It is idempotent — safe to re-run.

## Deploy

Deployment is driven entirely by the `terraform` workflow:

- **Open a pull request** that touches `terraform/**` → Actions runs
  `fmt`/`validate`, and Atlantis comments a `terraform plan` on the PR.
- **Merge to `main`** → Actions runs `terraform apply` in order
  (`vpc` → `eks` → `atlantis`).

For the first ever deploy, merge to `main` (or push the initial commit) so
all three modules apply in sequence. The Atlantis `LoadBalancer` can take a few
minutes to get a public hostname.

GitHub credentials for Atlantis are passed to Terraform from the Actions secrets
above (never committed), stored in a Kubernetes Secret on the cluster.

## Access the cluster (AWS CloudShell)

Open **AWS CloudShell** from the AWS Console (no install needed) and point
`kubectl` at the cluster:

```bash
aws eks update-kubeconfig --name atlantis-eks --region eu-north-1
kubectl get nodes
```

The project provisions two IAM roles for human access:

- `eks-admin` → full cluster admin
- `eks-read-only` → view-only access

Assume one of them before updating kubeconfig to use that level of access:

```bash
aws eks update-kubeconfig --name atlantis-eks --region eu-north-1 \
  --role-arn arn:aws:iam::<account-id>:role/eks-admin
```

## Connect Atlantis to GitHub

1. **Get the Atlantis URL.** In CloudShell, wait for AWS to assign a hostname to
   the `LoadBalancer` service:

   ```bash
   kubectl -n atlantis get svc atlantis \
     -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
   ```

   The webhook endpoint is `http://<hostname>/events`.

2. **Add the webhook** in the GitHub repo → Settings → Webhooks → Add webhook:
   - **Payload URL:** `http://<hostname>/events`
   - **Content type:** `application/json`
   - **Secret:** the same value as the `ATLANTIS_GITHUB_WEBHOOK_SECRET` Actions
     secret
   - **Events:** select *Let me select individual events* and check
     **Pull requests**, **Pushes**, **Issue comments**, and
     **Pull request reviews**.

3. GitHub will send a ping; a green check on the webhook means Atlantis is
   reachable.

> The repo (or its org) must be covered by the `ATLANTIS_REPO_ALLOWLIST`
> variable, and the `ATLANTIS_GITHUB_USER`'s token must have access to it.

## Verify Atlantis

Open a pull request in this repo — Atlantis should comment with a
`terraform plan` output automatically.

Applies are handled by GitHub Actions on merge to `main` (Atlantis has a
read-only role on this repo), so you don't run `atlantis apply` here — just
merge the PR and Actions applies it.

## Structure
```
.github/workflows/
├── terraform.yml            # validate on PR, apply on merge (vpc → eks → atlantis)
├── terraform-module.yml     # reusable per-module init/validate/apply
├── terraform-destroy.yml    # manual teardown (atlantis → eks → vpc)
└── bootstrap-backend.yml    # one-time S3 + DynamoDB state backend setup

atlantis.yaml                # Atlantis repo config: projects + plan workflow

terraform/
├── vpc/        # VPC and subnets
├── eks/        # EKS cluster, IAM roles, autoscaling, EBS CSI driver
└── atlantis/   # Helm release, IRSA role, default gp3 StorageClass
```