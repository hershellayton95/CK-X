#!/bin/bash
set -e
# Setup for Question 13: Gateway API CRDs, Gateway, backend Services and the
# old Ingress that must be replaced by an HTTPRoute.
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml >/dev/null
kubectl wait --for=condition=established --timeout=120s \
  crd/gateways.gateway.networking.k8s.io \
  crd/httproutes.gateway.networking.k8s.io >/dev/null

kubectl create namespace project-r500 --dry-run=client -o yaml | kubectl apply -f - >/dev/null

kubectl apply -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: main
  namespace: project-r500
spec:
  gatewayClassName: nginx
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      hostname: r500.gateway
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-desktop
  namespace: project-r500
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-desktop
  template:
    metadata:
      labels:
        app: web-desktop
    spec:
      containers:
        - name: nginx
          image: nginx:1-alpine
---
apiVersion: v1
kind: Service
metadata:
  name: web-desktop
  namespace: project-r500
spec:
  selector:
    app: web-desktop
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-mobile
  namespace: project-r500
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-mobile
  template:
    metadata:
      labels:
        app: web-mobile
    spec:
      containers:
        - name: nginx
          image: nginx:1-alpine
---
apiVersion: v1
kind: Service
metadata:
  name: web-mobile
  namespace: project-r500
spec:
  selector:
    app: web-mobile
  ports:
    - port: 80
      targetPort: 80
EOF

mkdir -p /tmp/exam/13
cat > /tmp/exam/13/ingress.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: r500
  namespace: project-r500
spec:
  rules:
    - host: r500.gateway
      http:
        paths:
          - path: /desktop
            pathType: Prefix
            backend:
              service:
                name: web-desktop
                port:
                  number: 80
          - path: /mobile
            pathType: Prefix
            backend:
              service:
                name: web-mobile
                port:
                  number: 80
EOF

kubectl apply -f /tmp/exam/13/ingress.yaml >/dev/null
kubectl -n project-r500 rollout status deployment/web-desktop --timeout=180s >/dev/null 2>&1 || true
kubectl -n project-r500 rollout status deployment/web-mobile --timeout=180s >/dev/null 2>&1 || true

echo "Setup completed for Question 13"
