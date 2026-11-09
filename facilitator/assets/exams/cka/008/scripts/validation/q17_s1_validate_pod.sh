#!/bin/bash
NS=project-tiger
if ! kubectl -n "$NS" get pod tigers-reunite >/dev/null 2>&1; then
  echo "❌ Pod tigers-reunite does not exist in $NS"
  exit 1
fi
IMG=$(kubectl -n "$NS" get pod tigers-reunite -o jsonpath='{.spec.containers[0].image}' 2>/dev/null)
PODLABEL=$(kubectl -n "$NS" get pod tigers-reunite -o jsonpath='{.metadata.labels.pod}' 2>/dev/null)
CONTAINERLABEL=$(kubectl -n "$NS" get pod tigers-reunite -o jsonpath='{.metadata.labels.container}' 2>/dev/null)
PHASE=$(kubectl -n "$NS" get pod tigers-reunite -o jsonpath='{.status.phase}' 2>/dev/null)
[ "$IMG" = "httpd:2-alpine" ] || { echo "❌ Pod image is '${IMG:-none}', expected httpd:2-alpine"; exit 1; }
[ "$PODLABEL" = "container" ] || { echo "❌ Pod label pod is '${PODLABEL:-none}', expected container"; exit 1; }
[ "$CONTAINERLABEL" = "pod" ] || { echo "❌ Pod label container is '${CONTAINERLABEL:-none}', expected pod"; exit 1; }
[ "$PHASE" = "Running" ] || { echo "❌ Pod phase is '${PHASE:-none}', expected Running"; exit 1; }
echo "✅ Pod tigers-reunite has the required labels, image and is Running"
exit 0
