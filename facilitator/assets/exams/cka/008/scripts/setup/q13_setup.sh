#!/bin/bash
set -e
# Setup for Question 13: a real Gateway API environment backed by NGINX Gateway
# Fabric. The backends return a fixed body so the routes can be checked with
# curl from the exam machine.
mkdir -p /tmp/exam/13

# Gateway API CRDs
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml >/dev/null
kubectl wait --for=condition=established --timeout=180s \
  crd/gateways.gateway.networking.k8s.io \
  crd/httproutes.gateway.networking.k8s.io >/dev/null

# NGINX Gateway Fabric controller and data plane (idempotent).
helm upgrade --install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  --version 1.6.0 \
  --namespace nginx-gateway --create-namespace \
  --set service.type=NodePort \
  --set service.externalTrafficPolicy=Cluster \
  --wait --timeout 10m >/dev/null

# Pin the HTTP NodePort to 30080 so it matches the k3d port mapping.
for attempt in $(seq 1 20); do
  NODEPORT=$(kubectl -n nginx-gateway get svc ngf-nginx-gateway-fabric \
    -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}' 2>/dev/null || true)
  [ "$NODEPORT" = "30080" ] && break
  kubectl -n nginx-gateway patch svc ngf-nginx-gateway-fabric \
    -p '{"spec":{"ports":[{"port":80,"nodePort":30080}]}}' >/dev/null 2>&1 || true
  sleep 3
done

# Let the exam machine resolve the Gateway hostname to the cluster host.
CLUSTER_IP=$(getent hosts k8s-api-server | awk '{print $1; exit}')
if [ -n "$CLUSTER_IP" ] && ! grep -q 'r500.gateway' /etc/hosts; then
  echo "$CLUSTER_IP r500.gateway" >> /etc/hosts
fi

kubectl create namespace project-r500 --dry-run=client -o yaml | kubectl apply -f - >/dev/null

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-desktop-content
  namespace: project-r500
data:
  default.conf: |
    server {
      listen 80;
      location / {
        return 200 "web-desktop";
      }
    }
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-mobile-content
  namespace: project-r500
data:
  default.conf: |
    server {
      listen 80;
      location / {
        return 200 "web-mobile";
      }
    }
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
          volumeMounts:
            - name: content
              mountPath: /etc/nginx/conf.d/default.conf
              subPath: default.conf
      volumes:
        - name: content
          configMap:
            name: web-desktop-content
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
          volumeMounts:
            - name: content
              mountPath: /etc/nginx/conf.d/default.conf
              subPath: default.conf
      volumes:
        - name: content
          configMap:
            name: web-mobile-content
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
---
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
EOF

# The old Ingress that must be replaced by the HTTPRoute.
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
kubectl -n project-r500 delete httproute traffic-director --ignore-not-found >/dev/null 2>&1 || true

kubectl -n project-r500 rollout status deployment/web-desktop --timeout=180s >/dev/null 2>&1 || true
kubectl -n project-r500 rollout status deployment/web-mobile --timeout=180s >/dev/null 2>&1 || true

# Wait for the Gateway to be programmed by the controller.
for attempt in $(seq 1 40); do
  PROGRAMMED=$(kubectl -n project-r500 get gateway main \
    -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null || true)
  [ "$PROGRAMMED" = "True" ] && break
  sleep 3
done

echo "Setup completed for Question 13"
