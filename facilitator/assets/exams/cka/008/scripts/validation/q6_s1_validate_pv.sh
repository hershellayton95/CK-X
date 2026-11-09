#!/bin/bash
if ! kubectl get pv safari-pv >/dev/null 2>&1; then
  echo "❌ PersistentVolume safari-pv does not exist"
  exit 1
fi
CAP=$(kubectl get pv safari-pv -o jsonpath='{.spec.capacity.storage}' 2>/dev/null)
AM=$(kubectl get pv safari-pv -o jsonpath='{.spec.accessModes[0]}' 2>/dev/null)
HP=$(kubectl get pv safari-pv -o jsonpath='{.spec.hostPath.path}' 2>/dev/null)
SC=$(kubectl get pv safari-pv -o jsonpath='{.spec.storageClassName}' 2>/dev/null)
[ "$CAP" = "2Gi" ] || { echo "❌ PV capacity is '${CAP:-none}', expected 2Gi"; exit 1; }
[ "$AM" = "ReadWriteOnce" ] || { echo "❌ PV access mode is '${AM:-none}', expected ReadWriteOnce"; exit 1; }
[ "$HP" = "/Volumes/Data" ] || { echo "❌ PV hostPath is '${HP:-none}', expected /Volumes/Data"; exit 1; }
[ -z "$SC" ] || { echo "❌ PV has storageClassName '${SC}', expected none"; exit 1; }
echo "✅ PV safari-pv has the required spec"
exit 0
