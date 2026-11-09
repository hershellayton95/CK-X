#!/bin/bash
set -e
# Setup for Question 6: remove the default StorageClass annotation so a
# classless PVC can bind to the classless safari-pv.
kubectl create namespace project-t230 --dry-run=client -o yaml | kubectl apply -f - >/dev/null

DEFAULT_SCS=$(kubectl get storageclass -o json 2>/dev/null | jq -r '.items[] | select(.metadata.annotations["storageclass.kubernetes.io/is-default-class"] == "true") | .metadata.name' 2>/dev/null || true)
for sc in $DEFAULT_SCS; do
  kubectl annotate storageclass "$sc" storageclass.kubernetes.io/is-default-class- --overwrite >/dev/null 2>&1 || true
done

echo "Setup completed for Question 6"
