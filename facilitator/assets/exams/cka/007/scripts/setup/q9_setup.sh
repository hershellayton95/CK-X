#!/bin/bash
# Setup for Question 9: network policy with a wrong port and an unconstrained from-rule
# (source: KodeKloud Ultimate Mocks - cyan-pod troubleshooting)
kubectl create namespace cyan-ns --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cyan-app
  namespace: cyan-ns
spec:
  replicas: 2
  selector:
    matchLabels:
      app: cyan-app
  template:
    metadata:
      labels:
        app: cyan-app
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: cyan-svc
  namespace: cyan-ns
spec:
  selector:
    app: cyan-app
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: cyan-white
  namespace: cyan-ns
  labels:
    client: white
spec:
  nodeSelector:
    kubernetes.io/hostname: k3d-cluster-agent-0
  restartPolicy: Never
  containers:
    - name: client
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: cyan-black
  namespace: cyan-ns
  labels:
    client: black
spec:
  nodeSelector:
    kubernetes.io/hostname: k3d-cluster-agent-0
  restartPolicy: Never
  containers:
    - name: client
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: cyan-np
  namespace: cyan-ns
spec:
  podSelector:
    matchLabels:
      app: cyan-app
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: cyan-ns
      ports:
        - port: 8080
EOF
exit 0
