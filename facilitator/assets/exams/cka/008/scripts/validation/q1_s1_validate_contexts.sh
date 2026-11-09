#!/bin/bash
F=/tmp/exam/1/contexts
if [ ! -s "$F" ]; then
  echo "❌ /tmp/exam/1/contexts is missing or empty"
  exit 1
fi
ACTUAL=$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$F" | grep -v '^$' | sort -u)
EXPECTED=$(printf '%s\n' cluster-admin cluster-w100 cluster-w200 | sort -u)
if [ "$ACTUAL" != "$EXPECTED" ]; then
  echo "❌ Context list is incorrect"
  echo "Found:"
  echo "$ACTUAL"
  echo "Expected:"
  echo "$EXPECTED"
  exit 1
fi
echo "✅ All three context names are listed"
exit 0
