#!/bin/bash
P=$(kubectl get svc web -n drill-variation-b -o jsonpath='{.spec.publishNotReadyAddresses}' 2>/dev/null)
if [ "$P" = "true" ]; then
  echo "publishNotReadyAddresses must not be set on Service web - unhealthy pods must never receive traffic"
  exit 1
fi
echo "publishNotReadyAddresses is not set"
exit 0
