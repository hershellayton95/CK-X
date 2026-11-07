#!/bin/bash
PH=$(kubectl get pvc mysql-alpha-pvc -n alpha -o jsonpath='{.status.phase}' 2>/dev/null)
VN=$(kubectl get pvc mysql-alpha-pvc -n alpha -o jsonpath='{.spec.volumeName}' 2>/dev/null)
if [ "$PH" != "Bound" ]; then
  echo "PVC phase is '${PH:-none}', expected Bound"
  exit 1
fi
if [ "$VN" != "alpha-pv" ]; then
  echo "PVC is bound to '${VN:-none}', expected alpha-pv"
  exit 1
fi
echo "PVC mysql-alpha-pvc is Bound to alpha-pv"
exit 0
