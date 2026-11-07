#!/bin/bash
U=$(kubectl get node k3d-cluster-agent-1 -o jsonpath='{.spec.unschedulable}' 2>/dev/null)
if [ "$U" = "true" ]; then
  echo "Node k3d-cluster-agent-1 is still cordoned"
  exit 1
fi
echo "Node k3d-cluster-agent-1 is schedulable"
exit 0
