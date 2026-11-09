#!/bin/bash
F=/tmp/exam/4/pods-terminated-first.txt
if [ ! -s "$F" ]; then
  echo "❌ /tmp/exam/4/pods-terminated-first.txt is missing or empty"
  exit 1
fi
echo "✅ The answer file exists and is not empty"
exit 0
