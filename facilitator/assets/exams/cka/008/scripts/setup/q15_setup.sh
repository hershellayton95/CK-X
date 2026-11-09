#!/bin/bash
set -e
# Setup for Question 15: backend, database and vault Pods for the egress
# NetworkPolicy exercise. Each Pod runs nginx on its own port.
kubectl create namespace project-snake --dry-run=client -o yaml | kubectl apply -f - >/dev/null

make_pod() {
  local name="$1" app="$2" port="$3"
  kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ${name}
  namespace: project-snake
  labels:
    app: ${app}
spec:
  containers:
    - name: nginx
      image: nginx:1-alpine
      ports:
        - containerPort: ${port}
      command: ["/bin/sh", "-c"]
      args: ["sed -i 's/listen[[:space:]]*80;/listen       ${port};/' /etc/nginx/conf.d/default.conf && exec nginx -g 'daemon off;'"]
EOF
}

make_pod backend-0 backend 80
make_pod db1-0 db1 1111
make_pod db2-0 db2 2222
make_pod vault-0 vault 3333

kubectl -n project-snake wait --for=condition=Ready pod --all --timeout=180s >/dev/null 2>&1 || true
echo "Setup completed for Question 15"
