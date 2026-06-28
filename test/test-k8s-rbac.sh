#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${RESULTS_DIR:-$SCRIPT_DIR/results}"
mkdir -p "$RESULTS_DIR"
exec > >(tee "$RESULTS_DIR/test-k8s-rbac.txt") 2>&1

REGION="${AWS_REGION:-eu-north-1}"
CLUSTER="${CLUSTER_NAME:-atlantis-eks}"
ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"

ADMIN_ROLE="arn:aws:iam::${ACCOUNT}:role/eks-admin"
RO_ROLE="arn:aws:iam::${ACCOUNT}:role/eks-read-only"

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

can_i() {
  kubectl auth can-i "$@" 2>/dev/null || true
}

use_role() {
  if ! aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" \
    --role-arn "$1" --alias "$2" >/dev/null 2>&1; then
    echo "  ERROR: could not configure kubeconfig for $1"
    echo "         (is your principal allowed to assume this role?)"
    return 1
  fi
  kubectl config use-context "$2" >/dev/null
}

echo "Cluster: $CLUSTER   Region: $REGION   Account: $ACCOUNT"
echo

echo "== Access entries / policies (AWS side) =="
if aws eks list-access-entries --cluster-name "$CLUSTER" --region "$REGION" >/dev/null 2>&1; then
  for role in "$ADMIN_ROLE" "$RO_ROLE"; do
    echo "  $role:"
    aws eks list-associated-access-policies --cluster-name "$CLUSTER" --region "$REGION" \
      --principal-arn "$role" --query 'associatedAccessPolicies[].policyArn' --output text \
      | sed 's/^/    /'
  done
else
  echo "  (AWS CLI too old for access-entry APIs; relying on the kubectl checks below)"
fi
echo

echo "== eks-admin: expect full access =="
if use_role "$ADMIN_ROLE" eks-admin-test; then
  check "admin: can do everything (* *)"      "$(can_i '*' '*')"               "yes"
  check "admin: can create deployments"       "$(can_i create deployments -A)" "yes"
  check "admin: can delete nodes"             "$(can_i delete nodes)"          "yes"
  check "admin: can create namespaces"        "$(can_i create namespaces)"     "yes"
fi
echo

echo "== eks-read-only: expect reads only =="
if use_role "$RO_ROLE" eks-read-only-test; then
  check "read-only: can get pods"             "$(can_i get pods -A)"           "yes"
  check "read-only: can list services"        "$(can_i list services -A)"      "yes"
  check "read-only: CANNOT list nodes (view excludes nodes)" "$(can_i list nodes)" "no"
  check "read-only: CANNOT create deployments" "$(can_i create deployments)"   "no"
  check "read-only: CANNOT delete pods"       "$(can_i delete pods)"           "no"
  check "read-only: CANNOT create namespaces" "$(can_i create namespaces)"     "no"
fi
echo

echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
