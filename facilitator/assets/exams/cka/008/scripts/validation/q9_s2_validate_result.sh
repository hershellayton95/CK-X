#!/bin/bash
F=/tmp/exam/9/result.json
if [ ! -s "$F" ]; then
  echo "❌ /tmp/exam/9/result.json is missing or empty"
  exit 1
fi
if ! jq -e '.kind == "SecretList" and ((.items // []) | length > 0)' "$F" >/dev/null 2>&1; then
  echo "❌ result.json is not a non-empty SecretList"
  exit 1
fi
echo "✅ result.json is a SecretList containing at least one Secret"
exit 0
