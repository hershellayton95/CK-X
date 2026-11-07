#!/bin/bash
R=$(kubectl get deploy web -n drill-variation-b -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [ "${R:-0}" -ne 3 ]; then
  echo "Deployment web has ${R:-0} ready replicas, expected 3"
  exit 1
fi
READY=$(kubectl get endpointslice -n drill-variation-b -l kubernetes.io/service-name=web -o json 2>/dev/null | jq -r '[.items[] | .endpoints[]? | select(.conditions.ready==true)] | length')
if [ "${READY:-0}" -lt 3 ]; then
  echo "Service web has ${READY:-0} ready endpoints, expected 3"
  exit 1
fi
echo "All 3 web pods Ready with 3 ready endpoints"
exit 0
