#!/bin/bash
FAILED=0
for ns in api-gateway-staging api-gateway-prod; do
  if kubectl -n "$ns" get configmap horizontal-scaling-config >/dev/null 2>&1; then
    echo "❌ ConfigMap horizontal-scaling-config still exists in namespace $ns"
    FAILED=1
  fi
done
if [ "$FAILED" -ne 0 ]; then
  exit 1
fi
echo "✅ The ConfigMaps are gone from both namespaces"
exit 0
