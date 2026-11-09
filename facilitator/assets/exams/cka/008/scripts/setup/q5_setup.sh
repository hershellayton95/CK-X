#!/bin/bash
set -e
# Setup for Question 5: Kustomize tree for api-gateway in staging and prod.
kubectl create namespace api-gateway-staging --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl create namespace api-gateway-prod --dry-run=client -o yaml | kubectl apply -f - >/dev/null

BASE=/tmp/exam/5/api-gateway
mkdir -p "$BASE/base" "$BASE/staging" "$BASE/prod"

cat > "$BASE/base/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - api-gateway.yaml
EOF

cat > "$BASE/base/api-gateway.yaml" <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: api-gateway
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: horizontal-scaling-config
data:
  horizontal-scaling: "70"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
spec:
  replicas: 1
  selector:
    matchLabels:
      id: api-gateway
  template:
    metadata:
      labels:
        id: api-gateway
    spec:
      serviceAccountName: api-gateway
      containers:
        - name: httpd
          image: httpd:2-alpine
          resources:
            requests:
              cpu: 10m
              memory: 20Mi
EOF

cat > "$BASE/staging/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: api-gateway-staging
resources:
  - ../base
patches:
  - path: api-gateway.yaml
EOF

cat > "$BASE/staging/api-gateway.yaml" <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: horizontal-scaling-config
data:
  horizontal-scaling: "60"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
  labels:
    env: staging
EOF

cat > "$BASE/prod/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: api-gateway-prod
resources:
  - ../base
patches:
  - path: api-gateway.yaml
EOF

cat > "$BASE/prod/api-gateway.yaml" <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: horizontal-scaling-config
data:
  horizontal-scaling: "80"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
  labels:
    env: prod
EOF

cd "$BASE"
kubectl kustomize staging | kubectl apply -f - >/dev/null
kubectl kustomize prod | kubectl apply -f - >/dev/null

echo "Setup completed for Question 5"
