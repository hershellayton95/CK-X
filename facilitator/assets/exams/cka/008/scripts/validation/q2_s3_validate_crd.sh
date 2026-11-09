#!/bin/bash
if ! kubectl get crd clusterissuers.cert-manager.io >/dev/null 2>&1; then
  echo "❌ CRD clusterissuers.cert-manager.io is not installed"
  exit 1
fi
echo "✅ The cert-manager ClusterIssuer CRD is installed"
exit 0
