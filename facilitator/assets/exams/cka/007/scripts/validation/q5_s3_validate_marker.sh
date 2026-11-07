#!/bin/bash
PODS=$(kubectl get pods -n maintenance -l job-name=maintenance-marker -o name 2>/dev/null)
if [ -n "$PODS" ]; then
  echo "maintenance-marker pods still exist ($PODS) - the node was not drained (use kubectl drain with --ignore-daemonsets)"
  exit 1
fi
echo "maintenance-marker pods were evicted"
exit 0
