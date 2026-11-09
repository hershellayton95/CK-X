#!/bin/bash
NS=project-snake
JSON=$(kubectl -n "$NS" get networkpolicy np-backend -o json 2>/dev/null)
if [ -z "$JSON" ]; then
  echo "❌ NetworkPolicy np-backend does not exist in $NS"
  exit 1
fi
if ! echo "$JSON" | jq -e '
  def sel($app): (.to // []) | any(.[]; (.podSelector.matchLabels.app // "") == $app);
  def ports_ok($app; $port):
    ([.spec.egress[] | select(sel($app)) | select((.ports // []) | length == 0)] | length) == 0 and
    ([.spec.egress[] | select(sel($app)) | .ports[]? | select((.port // -1) != $port)] | length) == 0 and
    ([.spec.egress[] | select(sel($app)) | .ports[]? | select(.port == $port and ((.protocol // "TCP") == "TCP"))] | length) >= 1;
  ports_ok("db1"; 1111) and
  ports_ok("db2"; 2222) and
  ([.spec.egress[] | select((sel("db1") or sel("db2")) | not)] | length) == 0
' >/dev/null 2>&1; then
  echo "❌ Egress rules must allow exactly db1:1111 and db2:2222 and nothing else"
  exit 1
fi
echo "✅ Two egress rules allow exactly db1:1111 and db2:2222"
exit 0
