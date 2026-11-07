#!/bin/bash
# Setup for Question 7: deployments to export with custom-columns
# (source: KodeKloud Lightning Lab 1 Q2)
mkdir -p /tmp/exam/outputs
rm -f /tmp/exam/outputs/admin2406_data
kubectl create namespace admin2406 --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
  namespace: admin2406
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api-server
  template:
    metadata:
      labels:
        app: api-server
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cache-layer
  namespace: admin2406
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cache-layer
  template:
    metadata:
      labels:
        app: cache-layer
    spec:
      containers:
        - name: cache
          image: busybox:1.36
          command: ["sh", "-c", "sleep 3600"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-frontend
  namespace: admin2406
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-frontend
  template:
    metadata:
      labels:
        app: web-frontend
    spec:
      containers:
        - name: nginx
          image: nginx:1.28
EOF
exit 0
