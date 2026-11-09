#!/bin/bash
# Setup for Question 7: resource usage scripts and a metrics API.
mkdir -p /tmp/exam/7
rm -f /tmp/exam/7/node.sh /tmp/exam/7/pod.sh

if ! kubectl get deployment metrics-server -n kube-system >/dev/null 2>&1; then
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml >/dev/null 2>&1 || true
  if kubectl get deployment metrics-server -n kube-system >/dev/null 2>&1; then
    kubectl -n kube-system patch deployment metrics-server --type=json \
      -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]' >/dev/null 2>&1 || true
    kubectl -n kube-system rollout status deployment/metrics-server --timeout=120s >/dev/null 2>&1 || true
  fi
fi

echo "Setup completed for Question 7"
