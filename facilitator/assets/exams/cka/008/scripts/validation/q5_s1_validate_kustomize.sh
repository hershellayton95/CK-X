#!/bin/bash
BASE=/tmp/exam/5/api-gateway
if [ ! -d "$BASE" ]; then
  echo "❌ Kustomize directory $BASE is missing"
  exit 1
fi
for env in staging prod; do
  OUT=$(cd "$BASE" && kubectl kustomize "$env" 2>&1)
  if [ $? -ne 0 ]; then
    echo "❌ The $env overlay does not build:"
    echo "$OUT"
    exit 1
  fi
  if echo "$OUT" | grep -q 'horizontal-scaling-config'; then
    echo "❌ The $env overlay still contains the horizontal-scaling-config ConfigMap"
    exit 1
  fi
done
echo "✅ Both overlays build and the ConfigMap is gone from both"
exit 0
