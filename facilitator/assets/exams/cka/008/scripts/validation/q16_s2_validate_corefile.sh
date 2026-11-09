#!/bin/bash
COREFILE=$(kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}' 2>/dev/null)
if [ -z "$COREFILE" ]; then
  echo "❌ Could not read the CoreDNS Corefile"
  exit 1
fi
LINE=$(echo "$COREFILE" | grep -E '^[[:space:]]*kubernetes[[:space:]]')
if [ -z "$LINE" ]; then
  echo "❌ The Corefile has no kubernetes plugin line"
  exit 1
fi
if ! echo "$LINE" | grep -q 'custom-domain'; then
  echo "❌ The kubernetes plugin line does not include custom-domain"
  exit 1
fi
if ! echo "$LINE" | grep -q 'cluster\.local'; then
  echo "❌ The kubernetes plugin line no longer includes cluster.local"
  exit 1
fi
echo "✅ The Corefile includes custom-domain alongside cluster.local"
exit 0
