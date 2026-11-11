#!/bin/bash
NS=project-tiger
JSON=$(kubectl -n "$NS" get pods -l id=very-important -o json 2>/dev/null)
TOTAL=$(echo "$JSON" | jq '.items | length' 2>/dev/null)
RUNNING=$(echo "$JSON" | jq '[.items[] | select(.status.phase == "Running")] | length' 2>/dev/null)
PENDING=$(echo "$JSON" | jq '[.items[] | select(.status.phase == "Pending")] | length' 2>/dev/null)
NODES=$(echo "$JSON" | jq '[.items[] | select(.status.phase == "Running") | .spec.nodeName] | unique | length' 2>/dev/null)
WORKERS=$(kubectl get nodes -o json 2>/dev/null | jq '[.items[] |
  select((.metadata.labels["node-role.kubernetes.io/control-plane"] // "") == "") |
  select(any(.status.conditions[]?; .type == "Ready" and .status == "True"))] | length' 2>/dev/null)
TOTAL=${TOTAL:-0}
WORKERS=${WORKERS:-0}
if [ "$TOTAL" -ne 3 ] || [ "$WORKERS" -lt 1 ]; then
  echo "❌ Expected 3 deploy-important Pods and at least 1 Ready worker node"
  echo "total=$TOTAL workers=$WORKERS"
  exit 1
fi
EXPECTED_RUNNING=$(( TOTAL < WORKERS ? TOTAL : WORKERS ))
EXPECTED_PENDING=$(( TOTAL - EXPECTED_RUNNING ))
if [ "${RUNNING:-0}" != "$EXPECTED_RUNNING" ] || [ "${PENDING:-0}" != "$EXPECTED_PENDING" ] || [ "${NODES:-0}" != "$EXPECTED_RUNNING" ]; then
  echo "❌ Expected $EXPECTED_RUNNING Running on distinct workers and $EXPECTED_PENDING Pending (workers=$WORKERS)"
  echo "running=${RUNNING:-0} pending=${PENDING:-0} distinctNodes=${NODES:-0}"
  exit 1
fi
echo "✅ $EXPECTED_RUNNING Pods run on distinct workers and $EXPECTED_PENDING are Pending"
exit 0
