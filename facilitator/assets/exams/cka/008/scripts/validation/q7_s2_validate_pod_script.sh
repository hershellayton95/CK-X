#!/bin/bash
F=/tmp/exam/7/pod.sh
if [ ! -s "$F" ]; then
  echo "❌ /tmp/exam/7/pod.sh is missing or empty"
  exit 1
fi
if ! grep -Eq 'kubectl[[:space:]]+top[[:space:]]+pods?([[:space:]]|$)' "$F"; then
  echo "❌ pod.sh does not run 'kubectl top pod'"
  exit 1
fi
if ! grep -Eq -- '--containers(=true)?' "$F"; then
  echo "❌ pod.sh does not request per-container usage with --containers"
  exit 1
fi
echo "✅ pod.sh uses kubectl top pod --containers"
exit 0
