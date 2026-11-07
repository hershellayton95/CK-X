#!/bin/bash
ALL=$(kubectl get pods -n logging -l app=log-shipper -o json 2>/dev/null | jq -r '[.items[] | select(.status.phase=="Running")] | length')
TOTAL=$(kubectl get pods -n logging -l app=log-shipper --no-headers 2>/dev/null | grep -c .)
if [ "${TOTAL:-0}" -eq 0 ]; then
  echo "no log-shipper pods found"
  exit 1
fi
if [ "$ALL" != "$TOTAL" ]; then
  echo "$ALL of $TOTAL log-shipper pods are Running"
  exit 1
fi
echo "All $TOTAL log-shipper pods are Running"
exit 0
