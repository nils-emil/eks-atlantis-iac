#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${RESULTS_DIR:-$SCRIPT_DIR/results}"
mkdir -p "$RESULTS_DIR"
exec > >(tee "$RESULTS_DIR/test-infrastructure.txt") 2>&1

REGION="${AWS_REGION:-eu-north-1}"
CLUSTER="${CLUSTER_NAME:-atlantis-eks}"

pass=0
fail=0

check() {
  if [ "$2" = "$3" ]; then
    echo "  PASS: $1 (got '$2')"
    pass=$((pass + 1))
  else
    echo "  FAIL: $1 (got '$2', want '$3')"
    fail=$((fail + 1))
  fi
}

echo "Cluster: $CLUSTER   Region: $REGION"
echo

echo "== VPC and subnets =="
vpc_count="$(aws ec2 describe-vpcs --region "$REGION" \
  --filters "Name=tag:Name,Values=${CLUSTER}-vpc" \
  --query 'length(Vpcs)' --output text)"
check "exactly 1 VPC" "$vpc_count" "1"

subnet_count="$(aws ec2 describe-subnets --region "$REGION" \
  --filters "Name=tag:kubernetes.io/cluster/${CLUSTER},Values=shared" \
  --query 'length(Subnets)' --output text)"
check "exactly 2 subnets" "$subnet_count" "2"
echo

echo "== EKS cluster =="
cluster_status="$(aws eks describe-cluster --name "$CLUSTER" --region "$REGION" \
  --query 'cluster.status' --output text 2>/dev/null || echo MISSING)"
check "cluster is ACTIVE" "$cluster_status" "ACTIVE"
echo

echo "== Worker node group scaling =="
ng="$(aws eks list-nodegroups --cluster-name "$CLUSTER" --region "$REGION" \
  --query 'nodegroups[0]' --output text 2>/dev/null || echo MISSING)"
if [ "$ng" != "MISSING" ] && [ -n "$ng" ]; then
  min="$(aws eks describe-nodegroup --cluster-name "$CLUSTER" --nodegroup-name "$ng" \
    --region "$REGION" --query 'nodegroup.scalingConfig.minSize' --output text)"
  max="$(aws eks describe-nodegroup --cluster-name "$CLUSTER" --nodegroup-name "$ng" \
    --region "$REGION" --query 'nodegroup.scalingConfig.maxSize' --output text)"
  check "node group minSize = 1" "$min" "1"
  check "node group maxSize = 2" "$max" "2"
else
  check "node group exists" "MISSING" "present"
fi
echo

echo "== IAM roles =="
for role in eks-admin eks-read-only; do
  got="$(aws iam get-role --role-name "$role" --query 'Role.RoleName' --output text 2>/dev/null || echo MISSING)"
  check "IAM role '$role' exists" "$got" "$role"
done
echo

echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
