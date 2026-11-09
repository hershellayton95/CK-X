#!/bin/bash
NS=project-r500
JSON=$(kubectl -n "$NS" get httproute traffic-director -o json 2>/dev/null)
if [ -z "$JSON" ]; then
  echo "❌ HTTPRoute traffic-director does not exist in $NS"
  exit 1
fi
if ! echo "$JSON" | jq -e '
  def route($p): [.spec.rules[] | select(any(.matches[]?; ((.path.value // "") == $p) and (((.headers // []) | length) == 0)))];
  (route("/desktop") | length) >= 1 and
  (route("/desktop") | all(.[]; ((.backendRefs // []) | any(.[]; .name == "web-desktop" and .port == 80)))) and
  (route("/mobile") | length) >= 1 and
  (route("/mobile") | all(.[]; ((.backendRefs // []) | any(.[]; .name == "web-mobile" and .port == 80))))
' >/dev/null 2>&1; then
  echo "❌ /desktop and /mobile routes do not target web-desktop:80 and web-mobile:80"
  exit 1
fi
echo "✅ Desktop and mobile routes target the correct Services"
exit 0
