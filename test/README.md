# Tests

Post-deploy verification scripts. They are **read-only** — `*-rbac` and
`*-infrastructure` only call `describe`/`list`/`auth can-i`, and create nothing.

Run them from **AWS CloudShell** (or any shell with the AWS CLI + `kubectl` and
valid AWS credentials).

| Script | Verifies | Needs |
|--------|----------|-------|
| `test-infrastructure.sh` | 1 VPC, 2 subnets, EKS ACTIVE, node group min 1 / max 2, `eks-admin` + `eks-read-only` roles exist | AWS creds |
| `test-k8s-rbac.sh` | `eks-admin` = full admin, `eks-read-only` = read-only | AWS creds able to assume both roles |
| `test-atlantis.sh` | Atlantis pod Running, PVC Bound, LoadBalancer hostname | kubeconfig pointed at the cluster |

## Run

```bash
# from the repo root
aws eks update-kubeconfig --name atlantis-eks --region eu-north-1

./test/test-infrastructure.sh
./test/test-k8s-rbac.sh
./test/test-atlantis.sh
```

Override defaults with env vars if your names differ:

```bash
AWS_REGION=eu-north-1 CLUSTER_NAME=atlantis-eks ./test/test-infrastructure.sh
```

Each script prints `PASS`/`FAIL` per check and exits non-zero if anything fails.
Output is also written to a `.txt` file under `test/results/`:

```
test/results/test-infrastructure.txt
test/results/test-k8s-rbac.txt
test/results/test-atlantis.txt
```

Override the location with `RESULTS_DIR=/some/path ./test/test-k8s-rbac.sh`.

## Notes

- `test-k8s-rbac.sh` switches kubeconfig context to assume each role. The
  principal you run as must be allowed to `sts:AssumeRole` on `eks-admin` /
  `eks-read-only` (the role trust policy allows the whole account by default).
- `kubectl auth can-i` returning `no` is the **expected** result for the
  read-only write checks — that is the test passing, not an error.
