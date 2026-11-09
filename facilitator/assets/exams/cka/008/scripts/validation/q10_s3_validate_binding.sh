#!/bin/bash
NS=project-hamster
if ! kubectl -n "$NS" get rolebinding processor >/dev/null 2>&1; then
  echo "❌ RoleBinding processor does not exist in $NS"
  exit 1
fi
if ! kubectl -n "$NS" get rolebinding processor -o json 2>/dev/null | jq -e '
  .roleRef.kind == "Role" and
  .roleRef.name == "processor" and
  any(.subjects[]?; .kind == "ServiceAccount" and .name == "processor" and .namespace == "project-hamster")
' >/dev/null 2>&1; then
  echo "❌ RoleBinding processor does not bind Role processor to the processor ServiceAccount"
  exit 1
fi
echo "✅ RoleBinding processor binds the Role to the ServiceAccount"
exit 0
