#!/bin/bash
NS=project-tiger
if ! kubectl -n "$NS" get deployment deploy-important >/dev/null 2>&1; then
  echo "❌ Deployment deploy-important does not exist in $NS"
  exit 1
fi
PODCOUNT=$(kubectl -n "$NS" get pods -l id=very-important --no-headers 2>/dev/null | grep -c .)
if [ "$PODCOUNT" -lt 1 ]; then
  echo "❌ No deploy-important Pods exist"
  exit 1
fi
COUNT=$(kubectl -n "$NS" get pods -l id=very-important -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' 2>/dev/null | grep -c '^k3d-cluster-server-0$')
if [ "$COUNT" != "0" ]; then
  echo "❌ $COUNT deploy-important Pod(s) run on the control-plane node"
  exit 1
fi
echo "✅ No deploy-important Pod runs on the control-plane node"
exit 0
