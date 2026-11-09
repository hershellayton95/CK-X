#!/bin/bash
F=/tmp/exam/1/current-context
if [ ! -s "$F" ]; then
  echo "❌ /tmp/exam/1/current-context is missing or empty"
  exit 1
fi
CURRENT=$(tr -d '[:space:]' < "$F")
if [ "$CURRENT" != "cluster-w200" ]; then
  echo "❌ Current context is '${CURRENT}', expected cluster-w200"
  exit 1
fi
echo "✅ Current context is cluster-w200"
exit 0
