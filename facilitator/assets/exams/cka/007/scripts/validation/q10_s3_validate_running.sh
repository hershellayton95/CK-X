#!/bin/bash
J=$(kubectl get pod init-demo -n init-ex -o json 2>/dev/null) || { echo "Pod init-demo not found"; exit 1; }
PH=$(echo "$J" | jq -r '.status.phase // "unknown"')
if [ "$PH" != "Running" ]; then
  echo "pod phase is '$PH', expected Running"
  exit 1
fi
READY=$(echo "$J" | jq -r '[.status.conditions[]? | select(.type=="Ready") | .status] | first // "False"')
if [ "$READY" != "True" ]; then
  echo "pod Ready condition is '$READY', expected True"
  exit 1
fi
EXIT=$(echo "$J" | jq -r '.status.initContainerStatuses[0].state.terminated.exitCode // "missing"')
if [ "$EXIT" != "0" ]; then
  echo "init container exit code is '$EXIT', expected 0 (it must complete before the app starts)"
  exit 1
fi
IMG=$(echo "$J" | jq -r '.spec.containers[] | select(.name=="app") | .image // "missing"')
if [ "$IMG" != "nginx:1.27" ]; then
  echo "main container app image is '$IMG', expected nginx:1.27"
  exit 1
fi
echo "Init container completed and app container Running with pod Ready"
exit 0
