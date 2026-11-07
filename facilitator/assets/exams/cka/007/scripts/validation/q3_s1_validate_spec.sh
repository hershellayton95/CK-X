#!/bin/bash
J=$(kubectl get ds log-shipper -n logging -o json 2>/dev/null) || { echo "DaemonSet log-shipper not found in logging"; exit 1; }
SEL=$(echo "$J" | jq -r '.spec.selector.matchLabels | to_entries | map("\(.key)=\(.value)") | sort | join(",")')
TPL=$(echo "$J" | jq -r '.spec.template.metadata.labels | to_entries | map("\(.key)=\(.value)") | sort | join(",")')
if [ "$SEL" != "app=log-shipper" ] || [ "$TPL" != "app=log-shipper" ]; then
  echo "selector='$SEL' template labels='$TPL', expected app=log-shipper on both"
  exit 1
fi
IMG=$(echo "$J" | jq -r '.spec.template.spec.containers[0].image // "missing"')
CMD=$(echo "$J" | jq -r '[.spec.template.spec.containers[0] | ((.command // []) + (.args // []))[]] | join(" ")')
NAME=$(echo "$J" | jq -r '.spec.template.spec.containers[0].name // "missing"')
if [ "$NAME" != "agent" ]; then
  echo "container name is '$NAME', expected agent"
  exit 1
fi
if [ "$IMG" != "busybox:1.36" ]; then
  echo "image is '$IMG', expected busybox:1.36"
  exit 1
fi
if ! echo "$CMD" | grep -q "sleep 3600"; then
  echo "command is '$CMD', expected to contain 'sleep 3600'"
  exit 1
fi
echo "DaemonSet spec correct (selector, labels, agent container, busybox:1.36, sleep loop)"
exit 0
