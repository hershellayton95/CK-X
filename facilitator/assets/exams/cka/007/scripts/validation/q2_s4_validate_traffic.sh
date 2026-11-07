#!/bin/bash
OUT=$(kubectl exec -n drill-variation-b deploy/report -- wget -qO- -T 5 http://web:80/ 2>/dev/null)
if ! echo "$OUT" | grep -qi "nginx"; then
  echo "http://web:80/ did not answer with nginx from inside the namespace"
  exit 1
fi
echo "http://web:80/ answers"
exit 0
