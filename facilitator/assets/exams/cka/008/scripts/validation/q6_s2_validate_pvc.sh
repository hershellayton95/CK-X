#!/bin/bash
NS=project-t230
if ! kubectl -n "$NS" get pvc safari-pvc >/dev/null 2>&1; then
  echo "❌ PersistentVolumeClaim safari-pvc does not exist in $NS"
  exit 1
fi
CAP=$(kubectl -n "$NS" get pvc safari-pvc -o jsonpath='{.spec.resources.requests.storage}' 2>/dev/null)
AM=$(kubectl -n "$NS" get pvc safari-pvc -o jsonpath='{.spec.accessModes[0]}' 2>/dev/null)
SC=$(kubectl -n "$NS" get pvc safari-pvc -o jsonpath='{.spec.storageClassName}' 2>/dev/null)
PHASE=$(kubectl -n "$NS" get pvc safari-pvc -o jsonpath='{.status.phase}' 2>/dev/null)
VOL=$(kubectl -n "$NS" get pvc safari-pvc -o jsonpath='{.spec.volumeName}' 2>/dev/null)
[ "$CAP" = "2Gi" ] || { echo "❌ PVC requests '${CAP:-none}', expected 2Gi"; exit 1; }
[ "$AM" = "ReadWriteOnce" ] || { echo "❌ PVC access mode is '${AM:-none}', expected ReadWriteOnce"; exit 1; }
[ -z "$SC" ] || { echo "❌ PVC has storageClassName '${SC}', expected none"; exit 1; }
[ "$PHASE" = "Bound" ] || { echo "❌ PVC phase is '${PHASE:-none}', expected Bound"; exit 1; }
[ "$VOL" = "safari-pv" ] || { echo "❌ PVC is bound to '${VOL:-none}', expected safari-pv"; exit 1; }
echo "✅ PVC safari-pvc has the required spec and is bound to safari-pv"
exit 0
