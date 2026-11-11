#!/bin/bash
set -e
# Setup for Question 8: create a worker node running an older Kubernetes version.
# k3d cannot upgrade a node in place, so the student must delete this node and
# create it again with the same k3s image as the control plane.
mkdir -p /tmp/exam/8

ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 \
  candidate@k8s-api-server "k3d node delete k3d-cka-node1-0" >/dev/null 2>&1 || true
kubectl delete node k3d-cka-node1-0 --ignore-not-found >/dev/null 2>&1 || true

OLD_IMAGE=rancher/k3s:v1.30.6-k3s1
for attempt in 1 2 3; do
  if ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 \
    candidate@k8s-api-server \
    "k3d node create cka-node1 --cluster cluster --role agent --image $OLD_IMAGE --wait" >/dev/null 2>&1; then
    break
  fi
  sleep 5
done

# Wait until the node is registered so the student sees a stable starting state.
for attempt in $(seq 1 40); do
  READY=$(kubectl get node k3d-cka-node1-0 \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
  [ "$READY" = "True" ] && break
  sleep 3
done

# Stop the outdated node: it is not usable and must not receive workloads.
ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 \
  candidate@k8s-api-server "docker stop k3d-cka-node1-0" >/dev/null 2>&1 || true

# Wait until the node is reported as NotReady.
for attempt in $(seq 1 40); do
  READY=$(kubectl get node k3d-cka-node1-0 \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
  [ -n "$READY" ] && [ "$READY" != "True" ] && break
  sleep 3
done

echo "Setup completed for Question 8"
