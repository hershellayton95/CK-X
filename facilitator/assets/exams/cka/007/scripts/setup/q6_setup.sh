#!/bin/bash
# Setup for Question 6: the secret to be mounted
# (source: KodeKloud Lightning Lab 1 Q7)
kubectl create namespace admin1401 --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: dotfile-secret
  namespace: admin1401
type: Opaque
stringData:
  username: admin
  password: s3cret
EOF
exit 0
