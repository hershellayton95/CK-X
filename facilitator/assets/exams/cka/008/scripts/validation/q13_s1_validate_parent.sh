#!/bin/bash
NS=project-r500
if ! kubectl -n "$NS" get httproute traffic-director >/dev/null 2>&1; then
  echo "❌ HTTPRoute traffic-director does not exist in $NS"
  exit 1
fi
if ! kubectl -n "$NS" get httproute traffic-director -o json 2>/dev/null | jq -e '
  any(.spec.parentRefs[]?; .name == "main") and
  ((.spec.hostnames // []) | index("r500.gateway") != null)
' >/dev/null 2>&1; then
  echo "❌ HTTPRoute does not reference Gateway main and hostname r500.gateway"
  exit 1
fi
echo "✅ HTTPRoute traffic-director references Gateway main and hostname r500.gateway"
exit 0
