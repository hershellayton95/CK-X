#!/bin/bash
set -e
# Setup for Question 14: build a kubeadm-style PKI directory at the default
# kubeadm location from the k3s control-plane certificates, so the real kubeadm
# cert commands work without --cert-dir.
PKI=/etc/kubernetes/pki
mkdir -p "$PKI" /tmp/exam/14

copy_tls_file() {
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 \
    candidate@k8s-api-server \
    "docker exec k3d-cluster-server-0 cat /var/lib/rancher/k3s/server/tls/$1" \
    > "$PKI/$2" 2>/dev/null
}

for attempt in 1 2 3 4 5; do
  if copy_tls_file serving-kube-apiserver.crt apiserver.crt \
    && copy_tls_file serving-kube-apiserver.key apiserver.key \
    && copy_tls_file server-ca.crt ca.crt \
    && copy_tls_file server-ca.key ca.key \
    && [ -s "$PKI/apiserver.crt" ] && [ -s "$PKI/ca.crt" ]; then
    chmod 600 "$PKI"/*.key
    echo "Setup completed for Question 14"
    exit 0
  fi
  sleep 3
done

echo "WARNING: could not copy the kube-apiserver certificates for Question 14"
exit 0
