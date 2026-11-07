#!/bin/bash
J=$(kubectl get pvc mysql-alpha-pvc -n alpha -o json 2>/dev/null) || { echo "PVC mysql-alpha-pvc not found in alpha"; exit 1; }
SZ=$(echo "$J" | jq -r '.spec.resources.requests.storage')
AM=$(echo "$J" | jq -r '.spec.accessModes[0] // "missing"')
SC=$(echo "$J" | jq -r '.spec.storageClassName // "missing"')
case "$SZ" in
  1Gi|1024Mi) ;;
  *) echo "PVC size is '$SZ', expected 1Gi (must match alpha-pv)"; exit 1;;
esac
if [ "$AM" != "ReadWriteOnce" ]; then
  echo "PVC accessMode is '$AM', expected ReadWriteOnce (must match alpha-pv)"
  exit 1
fi
if [ "$SC" != "slow" ]; then
  echo "PVC storageClassName is '$SC', expected slow (must match alpha-pv)"
  exit 1
fi
echo "PVC mysql-alpha-pvc matches alpha-pv (1Gi ReadWriteOnce slow)"
exit 0
