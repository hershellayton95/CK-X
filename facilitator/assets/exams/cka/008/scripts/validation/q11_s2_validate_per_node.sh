#!/bin/bash
NODES=$(kubectl get nodes --no-headers 2>/dev/null | awk '$2=="Ready"{print $1}' | sort)
NCOUNT=$(echo "$NODES" | grep -c .)
DESIRED=$(kubectl get ds ds-important -n project-tiger -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null)
CURRENT=$(kubectl get ds ds-important -n project-tiger -o jsonpath='{.status.currentNumberScheduled}' 2>/dev/null)
if [ "${DESIRED:-0}" != "$NCOUNT" ] || [ "${CURRENT:-0}" != "$NCOUNT" ]; then
  echo "DaemonSet desired=$DESIRED current=$CURRENT, cluster has $NCOUNT Ready nodes"
  exit 1
fi
PODNODES=$(kubectl get pods -n project-tiger -l id=ds-important -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' 2>/dev/null | sort)
PCOUNT=$(echo "$PODNODES" | grep -c .)
if [ "$PCOUNT" != "$NCOUNT" ]; then
  echo "found $PCOUNT ds-important pods, expected one per node ($NCOUNT)"
  exit 1
fi
MISSING=$(comm -23 <(echo "$NODES") <(echo "$PODNODES" | uniq))
if [ -n "$MISSING" ]; then
  echo "no ds-important pod on: $MISSING"
  exit 1
fi
DUPES=$(echo "$PODNODES" | uniq -d)
if [ -n "$DUPES" ]; then
  echo "more than one ds-important pod on: $DUPES"
  exit 1
fi
echo "Exactly one ds-important pod on each of the $NCOUNT nodes"
exit 0
