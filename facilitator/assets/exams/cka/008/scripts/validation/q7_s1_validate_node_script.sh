#!/bin/bash
F=/tmp/exam/7/node.sh
if [ ! -s "$F" ]; then
  echo "❌ /tmp/exam/7/node.sh is missing or empty"
  exit 1
fi
if ! grep -Eq 'kubectl[[:space:]]+top[[:space:]]+nodes?([[:space:]]|$)' "$F"; then
  echo "❌ node.sh does not run 'kubectl top node'"
  exit 1
fi
echo "✅ node.sh uses kubectl top node"
exit 0
