#!/bin/bash
J=$(kubectl get netpol cyan-np -n cyan-ns -o json 2>/dev/null) || { echo "NetworkPolicy cyan-np not found in cyan-ns - it must not be deleted"; exit 1; }
SEL=$(echo "$J" | jq -r '.spec.podSelector.matchLabels.app // "missing"')
if [ "$SEL" != "cyan-app" ]; then
  echo "policy podSelector app='$SEL', expected cyan-app"
  exit 1
fi
PT=$(echo "$J" | jq -r '.spec.policyTypes[]?' | grep -c Ingress)
if [ "$PT" -lt 1 ]; then
  echo "policyTypes must include Ingress"
  exit 1
fi
echo "NetworkPolicy cyan-np exists, selects cyan-app, declares Ingress"
exit 0
