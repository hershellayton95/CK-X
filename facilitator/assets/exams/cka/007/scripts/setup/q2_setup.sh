#!/bin/bash
# Setup for Question 2: readiness probe checks a path the app does not serve
# (source: kubeskills/cka-under-pressure variation-b; nginx answers on /)
kubectl create namespace drill-variation-b --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: drill-variation-b
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
          readinessProbe:
            httpGet:
              path: /ready
              port: 80
            initialDelaySeconds: 1
            periodSeconds: 3
---
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: drill-variation-b
spec:
  selector:
    app.kubernetes.io/name: web
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: report
  namespace: drill-variation-b
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
exit 0
