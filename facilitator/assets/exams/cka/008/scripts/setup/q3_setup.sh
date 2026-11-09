#!/bin/bash
set -e
# Setup for Question 3: StatefulSet with two replicas.
kubectl create namespace project-h800 --dry-run=client -o yaml | kubectl apply -f - >/dev/null

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: o3db
  namespace: project-h800
spec:
  clusterIP: None
  selector:
    app: o3db
  ports:
    - name: web
      port: 80
      targetPort: 80
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: o3db
  namespace: project-h800
spec:
  serviceName: o3db
  replicas: 2
  selector:
    matchLabels:
      app: o3db
  template:
    metadata:
      labels:
        app: o3db
    spec:
      containers:
        - name: nginx
          image: nginx:1-alpine
          ports:
            - containerPort: 80
EOF

kubectl -n project-h800 rollout status statefulset/o3db --timeout=180s >/dev/null 2>&1 || true
echo "Setup completed for Question 3"
