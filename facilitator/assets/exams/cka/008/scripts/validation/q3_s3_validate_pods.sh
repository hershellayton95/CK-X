#!/bin/bash
PODS=$(kubectl -n project-h800 get pods -l app=o3db -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null | grep -v '^$' | sort)
COUNT=$(echo "$PODS" | grep -c .)
if [ "$COUNT" != "1" ] || [ "$PODS" != "o3db-0" ]; then
  echo "❌ Expected only Pod o3db-0, found:"
  echo "${PODS:-none}"
  exit 1
fi
echo "✅ Only Pod o3db-0 remains"
exit 0
