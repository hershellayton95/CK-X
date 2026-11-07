#!/bin/bash
N=$(kubectl get pod secret-1401 -n admin1401 -o jsonpath='{.spec.nodeSelector.kubernetes\.io/hostname}' 2>/dev/null)
if [ "$N" != "k3d-cluster-agent-0" ]; then
  echo "nodeSelector is '${N:-none}', expected k3d-cluster-agent-0"
  exit 1
fi
echo "Pod scheduled via nodeSelector k3d-cluster-agent-0"
exit 0
