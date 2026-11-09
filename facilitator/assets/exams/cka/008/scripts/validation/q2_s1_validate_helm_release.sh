#!/bin/bash
if ! command -v helm >/dev/null 2>&1; then
  echo "❌ helm is not installed on the jumphost"
  exit 1
fi
if ! helm -n cert-manager list --deployed -o json 2>/dev/null \
  | jq -e 'any(.[]; .name == "cert-manager" and (.chart | startswith("cert-manager")))' >/dev/null 2>&1; then
  echo "❌ Helm release cert-manager is not deployed in namespace cert-manager"
  exit 1
fi
echo "✅ Helm release cert-manager is deployed"
exit 0
