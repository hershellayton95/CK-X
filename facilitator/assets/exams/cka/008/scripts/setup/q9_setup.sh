#!/bin/bash
set -e
# Setup for Question 9: ServiceAccount with permission to read Secrets.
mkdir -p /tmp/exam/9
kubectl create namespace project-swan --dry-run=client -o yaml | kubectl apply -f - >/dev/null

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: secret-reader
  namespace: project-swan
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: secret-reader
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: secret-reader
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: secret-reader
subjects:
  - kind: ServiceAccount
    name: secret-reader
    namespace: project-swan
---
apiVersion: v1
kind: Secret
metadata:
  name: example-secret
  namespace: project-swan
type: Opaque
stringData:
  username: demo
  password: demo-password
---
apiVersion: v1
kind: Secret
metadata:
  name: another-secret
  namespace: project-swan
type: Opaque
stringData:
  token: abc123
EOF

kubectl -n project-swan delete pod api-contact --ignore-not-found >/dev/null 2>&1 || true
echo "Setup completed for Question 9"
