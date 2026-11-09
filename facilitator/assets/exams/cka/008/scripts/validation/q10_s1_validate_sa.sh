#!/bin/bash
if ! kubectl -n project-hamster get serviceaccount processor >/dev/null 2>&1; then
  echo "❌ ServiceAccount processor does not exist in project-hamster"
  exit 1
fi
echo "✅ ServiceAccount processor exists"
exit 0
