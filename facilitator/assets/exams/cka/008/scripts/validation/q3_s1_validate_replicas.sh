#!/bin/bash
REPLICAS=$(kubectl -n project-h800 get statefulset o3db -o jsonpath='{.spec.replicas}' 2>/dev/null)
if [ "$REPLICAS" != "1" ]; then
  echo "❌ StatefulSet o3db requests '${REPLICAS:-none}' replicas, expected 1"
  exit 1
fi
echo "✅ StatefulSet o3db requests exactly 1 replica"
exit 0
