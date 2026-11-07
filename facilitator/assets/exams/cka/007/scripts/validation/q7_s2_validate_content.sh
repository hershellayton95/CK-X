#!/bin/bash
F=/tmp/exam/outputs/admin2406_data
if [ ! -f "$F" ]; then
  echo "output file $F does not exist"
  exit 1
fi
EXPECT=$(kubectl get deploy -n admin2406 -o json 2>/dev/null | jq -r '
  .items | sort_by(.metadata.name)[] |
  "\(.metadata.name) \(.spec.template.spec.containers[0].image) \(.status.readyReplicas // 0) admin2406"' | sort)
ACTUAL=$(tail -n +2 "$F" | awk 'NF' | awk '{$1=$1; print}' | sort)
if [ "$ACTUAL" != "$EXPECT" ]; then
  echo "file rows do not match the live deployments in admin2406"
  echo "--- expected ---"; echo "$EXPECT"
  echo "--- actual ---"; echo "$ACTUAL"
  exit 1
fi
echo "All rows match the live deployment state"
exit 0
