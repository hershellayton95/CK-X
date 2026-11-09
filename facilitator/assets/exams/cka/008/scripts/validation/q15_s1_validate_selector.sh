#!/bin/bash
NS=project-snake
if ! kubectl -n "$NS" get networkpolicy np-backend >/dev/null 2>&1; then
  echo "❌ NetworkPolicy np-backend does not exist in $NS"
  exit 1
fi
if ! kubectl -n "$NS" get networkpolicy np-backend -o json 2>/dev/null | jq -e '
  (.spec.podSelector.matchLabels.app // "") == "backend" and
  ((.spec.policyTypes // []) | sort) == ["Egress"]
' >/dev/null 2>&1; then
  echo "❌ NetworkPolicy must select app=backend and declare only Egress"
  exit 1
fi
echo "✅ NetworkPolicy selects app=backend and declares only Egress"
exit 0
