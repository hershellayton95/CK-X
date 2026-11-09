#!/bin/bash
F=/tmp/exam/16/coredns_backup.yaml
if [ ! -s "$F" ]; then
  echo "❌ /tmp/exam/16/coredns_backup.yaml is missing or empty"
  exit 1
fi
if ! grep -Eq '^kind:[[:space:]]*ConfigMap' "$F" || ! grep -Eq '^[[:space:]]*name:[[:space:]]*coredns' "$F"; then
  echo "❌ The backup does not look like the CoreDNS ConfigMap"
  exit 1
fi
echo "✅ The CoreDNS ConfigMap backup exists"
exit 0
