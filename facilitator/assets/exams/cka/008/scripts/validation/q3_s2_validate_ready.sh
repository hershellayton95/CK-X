#!/bin/bash
READY=$(kubectl -n project-h800 get statefulset o3db -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [ "$READY" != "1" ]; then
  echo "❌ StatefulSet o3db has '${READY:-0}' ready replicas, expected 1"
  exit 1
fi
echo "✅ StatefulSet o3db has 1 ready replica"
exit 0
