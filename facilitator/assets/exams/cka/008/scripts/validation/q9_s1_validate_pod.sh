#!/bin/bash
NS=project-swan
if ! kubectl -n "$NS" get pod api-contact >/dev/null 2>&1; then
  echo "❌ Pod api-contact does not exist in $NS"
  exit 1
fi
IMG=$(kubectl -n "$NS" get pod api-contact -o jsonpath='{.spec.containers[0].image}' 2>/dev/null)
SA=$(kubectl -n "$NS" get pod api-contact -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null)
[ "$IMG" = "nginx:1-alpine" ] || { echo "❌ Pod image is '${IMG:-none}', expected nginx:1-alpine"; exit 1; }
[ "$SA" = "secret-reader" ] || { echo "❌ Pod ServiceAccount is '${SA:-none}', expected secret-reader"; exit 1; }
echo "✅ Pod api-contact uses nginx:1-alpine and ServiceAccount secret-reader"
exit 0
