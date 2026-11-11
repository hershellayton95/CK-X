#!/bin/bash
F=/tmp/exam/14/kubeadm-renew-certs.sh
if [ ! -s "$F" ]; then
  echo "❌ $F is missing or empty"
  exit 1
fi
if ! grep -Eq '(^|[[:space:]/])kubeadm[[:space:]]+certs[[:space:]]+renew[[:space:]]+apiserver([[:space:]]|$)' "$F"; then
  echo "❌ Expected the kubeadm command that renews the kube-apiserver certificate, for example: kubeadm certs renew apiserver"
  exit 1
fi
echo "✅ The kubeadm certificate renewal command is present"
exit 0
