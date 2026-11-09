#!/bin/bash
NS=project-snake
VAULT_IP=$(kubectl -n "$NS" get pod vault-0 -o jsonpath='{.status.podIP}' 2>/dev/null)
DB2_IP=$(kubectl -n "$NS" get pod db2-0 -o jsonpath='{.status.podIP}' 2>/dev/null)
if [ -z "$VAULT_IP" ] || [ -z "$DB2_IP" ]; then
  echo "❌ Could not determine the vault-0 or db2-0 Pod IP"
  exit 1
fi
if kubectl -n "$NS" exec backend-0 -- wget -q -T 5 -O /dev/null "http://${VAULT_IP}:3333/" >/dev/null 2>&1; then
  echo "❌ Traffic from backend-0 to vault:3333 is still allowed"
  exit 1
fi
if kubectl -n "$NS" exec backend-0 -- wget -q -T 5 -O /dev/null "http://${DB2_IP}:1111/" >/dev/null 2>&1; then
  echo "❌ Traffic from backend-0 to db2:1111 is still allowed"
  exit 1
fi
echo "✅ Traffic to vault:3333 and db2:1111 is blocked"
exit 0
