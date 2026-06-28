#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${RESULTS_DIR:-$SCRIPT_DIR/results}"
mkdir -p "$RESULTS_DIR"
exec > >(tee "$RESULTS_DIR/test-atlantis.txt") 2>&1

NS="${ATLANTIS_NAMESPACE:-atlantis}"

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

echo "Namespace: $NS"
echo

pod_phase="$(kubectl -n "$NS" get pod atlantis-0 \
  -o jsonpath='{.status.phase}' 2>/dev/null || echo MISSING)"
check "atlantis-0 pod is Running" "$pod_phase" "Running"

pvc_status="$(kubectl -n "$NS" get pvc atlantis-data \
  -o jsonpath='{.status.phase}' 2>/dev/null || echo MISSING)"
check "atlantis-data PVC is Bound" "$pvc_status" "Bound"

lb_host="$(kubectl -n "$NS" get svc atlantis \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo '')"
if [ -n "$lb_host" ]; then
  check "LoadBalancer has a hostname" "present" "present"
  echo "  webhook endpoint: http://${lb_host}/events"
else
  check "LoadBalancer has a hostname" "missing" "present"
fi
echo

echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
