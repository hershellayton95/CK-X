#!/bin/bash
# Setup for Question 5: critical-db deployment + completed marker job pinned to the node
# that will be drained (backoffLimit 0: an evicted marker is never recreated)
# (source: theplatformlab mock exam Q4)
kubectl create namespace maintenance --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: critical-db
  namespace: maintenance
spec:
  replicas: 3
  selector:
    matchLabels:
      app: critical-db
  template:
    metadata:
      labels:
        app: critical-db
    spec:
      containers:
        - name: db
          image: nginx:1.27
          ports:
            - containerPort: 80
---
apiVersion: batch/v1
kind: Job
metadata:
  name: maintenance-marker
  namespace: maintenance
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      nodeSelector:
        kubernetes.io/hostname: k3d-cluster-agent-1
      containers:
        - name: marker
          image: busybox:1.36
          command: ["sh", "-c", "sleep 60"]
EOF
exit 0
