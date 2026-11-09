#!/bin/bash
NS=project-tiger
JSON=$(kubectl -n "$NS" get pods -l id=very-important -o json 2>/dev/null)
TOTAL=$(echo "$JSON" | jq '.items | length' 2>/dev/null)
RUNNING=$(echo "$JSON" | jq '[.items[] | select(.status.phase == "Running")] | length' 2>/dev/null)
PENDING=$(echo "$JSON" | jq '[.items[] | select(.status.phase == "Pending")] | length' 2>/dev/null)
NODES=$(echo "$JSON" | jq '[.items[] | select(.status.phase == "Running") | .spec.nodeName] | unique | length' 2>/dev/null)
if [ "${TOTAL:-0}" != "3" ] || [ "${RUNNING:-0}" != "2" ] || [ "${PENDING:-0}" != "1" ] || [ "${NODES:-0}" != "2" ]; then
  echo "❌ Expected 3 Pods: 2 Running on 2 distinct nodes and 1 Pending"
  echo "total=${TOTAL:-0} running=${RUNNING:-0} pending=${PENDING:-0} distinctNodes=${NODES:-0}"
  exit 1
fi
echo "✅ Two Pods run on distinct nodes and the third is Pending"
exit 0
