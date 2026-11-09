#!/bin/bash
NS=project-snake
if ! kubectl -n "$NS" get networkpolicy np-backend >/dev/null 2>&1; then
  echo "❌ NetworkPolicy np-backend does not exist in $NS"
  exit 1
fi
DB1_IP=$(kubectl -n "$NS" get pod db1-0 -o jsonpath='{.status.podIP}' 2>/dev/null)
DB2_IP=$(kubectl -n "$NS" get pod db2-0 -o jsonpath='{.status.podIP}' 2>/dev/null)
if [ -z "$DB1_IP" ] || [ -z "$DB2_IP" ]; then
  echo "❌ Could not determine the db1-0 or db2-0 Pod IP"
  exit 1
fi
if ! kubectl -n "$NS" exec backend-0 -- wget -q -T 5 -O /dev/null "http://${DB1_IP}:1111/" >/dev/null 2>&1; then
  echo "❌ Allowed traffic from backend-0 to db1:1111 failed"
  exit 1
fi
if ! kubectl -n "$NS" exec backend-0 -- wget -q -T 5 -O /dev/null "http://${DB2_IP}:2222/" >/dev/null 2>&1; then
  echo "❌ Allowed traffic from backend-0 to db2:2222 failed"
  exit 1
fi
echo "✅ Allowed traffic to db1:1111 and db2:2222 works"
exit 0
