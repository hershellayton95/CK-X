#!/bin/bash
set -e
# Setup for Question 4: Pods with different QoS classes.
mkdir -p /tmp/exam/4
kubectl create namespace project-c13 --dry-run=client -o yaml | kubectl apply -f - >/dev/null

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: c13-best-1
  namespace: project-c13
spec:
  containers:
    - name: nginx
      image: nginx:1-alpine
---
apiVersion: v1
kind: Pod
metadata:
  name: c13-best-2
  namespace: project-c13
spec:
  containers:
    - name: sleep
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: c13-burstable
  namespace: project-c13
spec:
  containers:
    - name: nginx
      image: nginx:1-alpine
      resources:
        requests:
          cpu: 50m
          memory: 64Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: c13-guaranteed
  namespace: project-c13
spec:
  containers:
    - name: nginx
      image: nginx:1-alpine
      resources:
        requests:
          cpu: 50m
          memory: 64Mi
        limits:
          cpu: 50m
          memory: 64Mi
EOF

kubectl -n project-c13 wait --for=condition=Ready pod --all --timeout=180s >/dev/null 2>&1 || true
echo "Setup completed for Question 4"
