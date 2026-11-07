#!/bin/bash
OUT=$(kubectl exec -n cyan-ns cyan-white -- wget -qO- -T 8 http://cyan-svc:80/ 2>/dev/null)
if ! echo "$OUT" | grep -qi "nginx"; then
  echo "cyan-white cannot reach http://cyan-svc:80/"
  exit 1
fi
echo "cyan-white can reach the app"
exit 0
