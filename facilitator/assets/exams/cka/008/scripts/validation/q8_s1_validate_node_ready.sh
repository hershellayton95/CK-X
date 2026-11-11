#!/bin/bash
NODE=k3d-cka-node1-0
if ! kubectl get node "$NODE" >/dev/null 2>&1; then
  echo "❌ Node $NODE does not exist"
  exit 1
fi
READY=$(kubectl get node "$NODE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
if [ "$READY" != "True" ]; then
  echo "❌ Node $NODE is not Ready (Ready='${READY:-unknown}')"
  exit 1
fi
CP_LABEL=$(kubectl get node "$NODE" -o json 2>/dev/null | jq -r '.metadata.labels["node-role.kubernetes.io/control-plane"] // ""')
if [ -n "$CP_LABEL" ]; then
  echo "❌ Node $NODE is a control-plane node"
  exit 1
fi
echo "✅ Node $NODE is Ready and is a worker"
exit 0
