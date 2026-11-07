#!/bin/bash
READY=$(kubectl get endpointslice -n drill-variation-a -l kubernetes.io/service-name=web -o json 2>/dev/null | jq -r '[.items[] | .endpoints[]? | select(.conditions.ready==true)] | length')
if [ "${READY:-0}" -lt 3 ]; then
  echo "Service web has ${READY:-0} ready endpoints, expected 3"
  exit 1
fi
OUT=$(kubectl exec -n drill-variation-a deploy/report -- wget -qO- -T 5 http://web:80/ 2>/dev/null)
if ! echo "$OUT" | grep -qi "nginx"; then
  echo "http://web:80/ did not answer with nginx from inside the namespace"
  exit 1
fi
echo "3 ready endpoints and http://web:80/ answers"
exit 0
