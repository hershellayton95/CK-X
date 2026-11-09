#!/bin/bash
NS=project-t230
if ! kubectl -n "$NS" get deployment safari >/dev/null 2>&1; then
  echo "❌ Deployment safari does not exist in $NS"
  exit 1
fi
if ! kubectl -n "$NS" get deployment safari -o json 2>/dev/null | jq -e '
  (.spec.template.spec.containers | any(.[]; .image == "httpd:2-alpine")) and
  (.spec.template.spec.containers | any(.[]; (.volumeMounts // []) | any(.[]; .mountPath == "/tmp/safari-data"))) and
  (.spec.template.spec.volumes | any(.[]; .persistentVolumeClaim.claimName == "safari-pvc"))
' >/dev/null 2>&1; then
  echo "❌ Deployment safari does not use httpd:2-alpine with safari-pvc mounted at /tmp/safari-data"
  exit 1
fi
READY=$(kubectl -n "$NS" get deployment safari -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
if [ "${READY:-0}" -lt 1 ]; then
  echo "❌ Deployment safari has no available replicas"
  exit 1
fi
echo "✅ Deployment safari mounts safari-pvc at /tmp/safari-data and is running"
exit 0
