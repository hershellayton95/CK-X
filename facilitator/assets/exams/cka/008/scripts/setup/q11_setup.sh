#!/bin/bash
set -e
# Setup for Question 11: taint the control-plane node so the DaemonSet needs
# an explicit toleration to place a Pod there.
kubectl create namespace project-tiger --dry-run=client -o yaml | kubectl apply -f - >/dev/null

if kubectl get node k3d-cluster-server-0 >/dev/null 2>&1; then
  kubectl taint nodes k3d-cluster-server-0 node-role.kubernetes.io/control-plane:NoSchedule --overwrite >/dev/null
else
  echo "WARNING: control-plane node k3d-cluster-server-0 not found"
fi

echo "Setup completed for Question 11"
