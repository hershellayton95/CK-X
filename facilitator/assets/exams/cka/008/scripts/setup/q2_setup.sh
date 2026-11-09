#!/bin/bash
# Setup for Question 2: cert-manager Helm repo and ClusterIssuer manifest.
mkdir -p /tmp/exam/2

helm repo add jetstack https://charts.jetstack.io --force-update >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1 || true

cat > /tmp/exam/2/cluster-issuer.yaml <<'EOF'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: course-issuer
spec:
  selfSigned: {}
EOF

echo "Setup completed for Question 2"
