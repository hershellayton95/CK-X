#!/bin/bash
NODES=$(kubectl get nodes --no-headers 2>/dev/null | awk '$2=="Ready"{print $1}' | sort)
NCOUNT=$(echo "$NODES" | grep -c .)
DESIRED=$(kubectl get ds log-shipper -n logging -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null)
CURRENT=$(kubectl get ds log-shipper -n logging -o jsonpath='{.status.currentNumberScheduled}' 2>/dev/null)
if [ "${DESIRED:-0}" != "$NCOUNT" ] || [ "${CURRENT:-0}" != "$NCOUNT" ]; then
  echo "DaemonSet desired=$DESIRED current=$CURRENT, cluster has $NCOUNT Ready nodes"
  exit 1
fi
PODNODES=$(kubectl get pods -n logging -l app=log-shipper -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' 2>/dev/null | sort)
PCOUNT=$(echo "$PODNODES" | grep -c .)
if [ "$PCOUNT" != "$NCOUNT" ]; then
  echo "found $PCOUNT log-shipper pods, expected one per node ($NCOUNT)"
  exit 1
fi
MISSING=$(comm -23 <(echo "$NODES") <(echo "$PODNODES" | uniq))
if [ -n "$MISSING" ]; then
  echo "no log-shipper pod on: $MISSING"
  exit 1
fi
DUPES=$(echo "$PODNODES" | uniq -d)
if [ -n "$DUPES" ]; then
  echo "more than one log-shipper pod on: $DUPES"
  exit 1
fi
echo "Exactly one log-shipper pod on each of the $NCOUNT nodes"
exit 0
