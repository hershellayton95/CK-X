#!/bin/bash
PH=$(kubectl get pod secret-1401 -n admin1401 -o jsonpath='{.status.phase}' 2>/dev/null)
if [ "$PH" != "Running" ]; then
  echo "pod phase is '${PH:-none}', expected Running"
  exit 1
fi
IMG=$(kubectl get pod secret-1401 -n admin1401 -o jsonpath='{.spec.containers[?(@.name=="secret-admin")].image}' 2>/dev/null)
if [ "$IMG" != "busybox:1.36" ]; then
  echo "container secret-admin image is '${IMG:-none}', expected busybox:1.36"
  exit 1
fi
FILES=$(kubectl exec -n admin1401 secret-1401 -- ls /etc/secret-volume 2>/dev/null)
if [ -z "$FILES" ]; then
  echo "/etc/secret-volume is empty or unreadable inside the pod"
  exit 1
fi
echo "Pod Running and secret files present at /etc/secret-volume"
exit 0
