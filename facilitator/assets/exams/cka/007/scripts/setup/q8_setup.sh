#!/bin/bash
# Setup for Question 8: deployment referencing a PVC that does not exist yet, plus the
# static PV it must bind to (source: KodeKloud Lightning Lab 1 Q5 - alpha-mysql)
kubectl create namespace alpha --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f - <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: slow
provisioner: rancher.io/local-path
volumeBindingMode: Immediate
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: alpha-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: slow
  hostPath:
    path: /opt/alpha
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alpha-mysql
  namespace: alpha
spec:
  replicas: 1
  selector:
    matchLabels:
      app: alpha-mysql
  template:
    metadata:
      labels:
        app: alpha-mysql
    spec:
      containers:
        - name: mysql
          image: busybox:1.36
          command: ["sh", "-c", "sleep 3600"]
          env:
            - name: MYSQL_ALLOW_EMPTY_PASSWORD
              value: "1"
          volumeMounts:
            - name: mysql-data
              mountPath: /var/lib/mysql
      volumes:
        - name: mysql-data
          persistentVolumeClaim:
            claimName: mysql-alpha-pvc
EOF
exit 0
