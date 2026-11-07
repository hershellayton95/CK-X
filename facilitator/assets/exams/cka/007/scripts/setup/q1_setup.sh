#!/bin/bash
# Setup for Question 1: service selector mismatch with pods that must never restart
# (source: kubeskills/cka-under-pressure variation-a)
kubectl create namespace drill-variation-a --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: drill-variation-a
spec:
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: web
  template:
    metadata:
      labels:
        app.kubernetes.io/name: web
    spec:
      nodeSelector:
        kubernetes.io/hostname: k3d-cluster-agent-0
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: drill-variation-a
spec:
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: report
  namespace: drill-variation-a
spec:
  replicas: 1
  selector:
    matchLabels:
      app: report
  template:
    metadata:
      labels:
        app: report
    spec:
      nodeSelector:
        kubernetes.io/hostname: k3d-cluster-agent-0
      containers:
        - name: report
          image: busybox:1.36
          command: ["sh", "-c", "sleep 3600"]
EOF
# Wait for the web pods, then record their identities: the question forbids
# restarting/replacing them, and the validation compares against this file.
kubectl -n drill-variation-a rollout status deploy/web --timeout=180s >/dev/null 2>&1
mkdir -p /tmp/exam
kubectl -n drill-variation-a get pods -l app.kubernetes.io/name=web \
  -o jsonpath='{range .items[*]}{.metadata.uid}{"\n"}{end}' | sort > /tmp/exam/variation_a_pods.txt
exit 0
