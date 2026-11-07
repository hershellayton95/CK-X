#!/bin/bash
J=$(kubectl get pod init-demo -n init-ex -o json 2>/dev/null) || { echo "Pod init-demo not found in init-ex"; exit 1; }
INIT=$(echo "$J" | jq -r '.spec.initContainers[0].name // "missing"')
IMG=$(echo "$J" | jq -r '.spec.initContainers[0].image // "missing"')
CMD=$(echo "$J" | jq -r '[.spec.initContainers[0] | ((.command // []) + (.args // []))[]] | join(" ")')
if [ "$INIT" != "init-setup" ]; then
  echo "first init container is '$INIT', expected init-setup"
  exit 1
fi
if [ "$IMG" != "busybox:1.36" ]; then
  echo "init container image is '$IMG', expected busybox:1.36"
  exit 1
fi
if ! echo "$CMD" | grep -q "sleep 10"; then
  echo "init container command is '$CMD', expected to contain 'sleep 10'"
  exit 1
fi
echo "init container init-setup defined correctly"
exit 0
