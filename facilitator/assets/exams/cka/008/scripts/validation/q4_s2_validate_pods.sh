#!/bin/bash
F=/tmp/exam/4/pods-terminated-first.txt
if [ ! -s "$F" ]; then
  echo "❌ /tmp/exam/4/pods-terminated-first.txt is missing or empty"
  exit 1
fi
EXPECTED=$(kubectl -n project-c13 get pods \
  -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.qosClass}{"\n"}{end}' 2>/dev/null \
  | awk '$2=="BestEffort"{print $1}' | sort -u)
ACTUAL=$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$F" | grep -v '^$' | sort -u)
if [ "$ACTUAL" != "$EXPECTED" ]; then
  echo "❌ The file does not list exactly the BestEffort Pods"
  echo "Found:"
  echo "${ACTUAL:-none}"
  echo "Expected:"
  echo "${EXPECTED:-none}"
  exit 1
fi
echo "✅ The file lists exactly the BestEffort Pods"
exit 0
