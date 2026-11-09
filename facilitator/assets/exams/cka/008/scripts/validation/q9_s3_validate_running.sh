#!/bin/bash
NS=project-swan
PHASE=$(kubectl -n "$NS" get pod api-contact -o jsonpath='{.status.phase}' 2>/dev/null)
READY=$(kubectl -n "$NS" get pod api-contact -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)
[ "$PHASE" = "Running" ] || { echo "❌ Pod api-contact phase is '${PHASE:-none}', expected Running"; exit 1; }
[ "$READY" = "true" ] || { echo "❌ Pod api-contact is not Ready"; exit 1; }
echo "✅ Pod api-contact is Running and Ready"
exit 0
