#!/bin/bash
SPEC=$(kubectl get deploy critical-db -n maintenance -o jsonpath='{.spec.replicas}' 2>/dev/null)
READY=$(kubectl get deploy critical-db -n maintenance -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [ "$SPEC" != "3" ] || [ "${READY:-0}" != "3" ]; then
  echo "critical-db has ${READY:-0}/${SPEC:-?} ready replicas, expected 3/3"
  exit 1
fi
echo "critical-db runs 3 ready replicas"
exit 0
