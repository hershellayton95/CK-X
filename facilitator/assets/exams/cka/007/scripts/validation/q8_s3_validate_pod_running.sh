#!/bin/bash
R=$(kubectl get deploy alpha-mysql -n alpha -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [ "${R:-0}" -lt 1 ]; then
  echo "Deployment alpha-mysql has ${R:-0} ready replicas - the pod is still not running (check the PVC)"
  exit 1
fi
PH=$(kubectl get pods -n alpha -l app=alpha-mysql -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
if [ "$PH" != "Running" ]; then
  echo "alpha-mysql pod phase is '${PH:-none}', expected Running"
  exit 1
fi
if ! kubectl get pv alpha-pv -o json 2>/dev/null | jq -e '
    .spec.capacity.storage=="1Gi" and
    .spec.accessModes==["ReadWriteOnce"] and
    .spec.hostPath.path=="/opt/alpha" and
    .spec.storageClassName=="slow"' >/dev/null; then
  echo "PersistentVolume alpha-pv was altered - it must not be changed"
  exit 1
fi
echo "Pod runs with the volume and alpha-pv is unaltered"
exit 0
