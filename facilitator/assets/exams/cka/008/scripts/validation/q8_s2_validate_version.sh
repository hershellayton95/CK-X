#!/bin/bash
NEW=k3d-cka-node1-0
CP=k3d-cluster-server-0
NEWV=$(kubectl get node "$NEW" -o jsonpath='{.status.nodeInfo.kubeletVersion}' 2>/dev/null)
CPV=$(kubectl get node "$CP" -o jsonpath='{.status.nodeInfo.kubeletVersion}' 2>/dev/null)
if [ -z "$NEWV" ] || [ -z "$CPV" ]; then
  echo "❌ Could not read the kubelet version from $NEW or $CP"
  exit 1
fi
if [ "$NEWV" != "$CPV" ]; then
  echo "❌ Node $NEW runs $NEWV, control plane runs $CPV"
  exit 1
fi
echo "✅ Node $NEW runs $NEWV, same as the control plane"
exit 0
