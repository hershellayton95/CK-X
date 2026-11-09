#!/bin/bash
NS=project-hamster
if ! kubectl -n "$NS" get role processor >/dev/null 2>&1; then
  echo "❌ Role processor does not exist in $NS"
  exit 1
fi
if ! kubectl -n "$NS" get role processor -o json 2>/dev/null | jq -e '
  ([.rules[].verbs[]] | unique) == ["create"] and
  ([.rules[].resources[]] | unique | sort) == ["configmaps", "secrets"] and
  ([.rules[].apiGroups[]] | unique | all(. == "" or . == "*"))
' >/dev/null 2>&1; then
  echo "❌ Role processor must allow only create on secrets and configmaps"
  exit 1
fi
SA=system:serviceaccount:project-hamster:processor
for res in secrets configmaps; do
  ANS=$(kubectl auth can-i create "$res" -n "$NS" --as="$SA" 2>/dev/null)
  [ "$ANS" = "yes" ] || { echo "❌ ServiceAccount cannot create $res"; exit 1; }
done
for verb in get list update patch delete; do
  for res in secrets configmaps; do
    ANS=$(kubectl auth can-i "$verb" "$res" -n "$NS" --as="$SA" 2>/dev/null)
    [ "$ANS" = "no" ] || { echo "❌ ServiceAccount should not be able to $verb $res"; exit 1; }
  done
done
echo "✅ Role processor allows only create on secrets and configmaps"
exit 0
