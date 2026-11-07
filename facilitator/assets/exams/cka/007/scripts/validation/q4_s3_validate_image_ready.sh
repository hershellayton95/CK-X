#!/bin/bash
IMG=$(kubectl get deploy web -n image-security -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
if [ "$IMG" != "nginx:1.27" ]; then
  echo "image is '${IMG:-none}', expected nginx:1.27 (do not change the image)"
  exit 1
fi
SPEC=$(kubectl get deploy web -n image-security -o jsonpath='{.spec.replicas}' 2>/dev/null)
READY=$(kubectl get deploy web -n image-security -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [ "${READY:-0}" != "$SPEC" ] || [ "${READY:-0}" -lt 1 ]; then
  echo "Deployment web has ${READY:-0}/${SPEC:-?} ready replicas"
  exit 1
fi
echo "Image unchanged (nginx:1.27) and deployment fully ready"
exit 0
