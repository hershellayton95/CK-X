#!/bin/bash
# Setup for Question 4: deployment that needs an imagePullSecret
# (source: KodeKloud Practice Test - Image Security)
kubectl create namespace image-security --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: image-security
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
EOF
exit 0
