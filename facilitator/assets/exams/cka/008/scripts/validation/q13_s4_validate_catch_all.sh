#!/bin/bash
NS=project-r500
JSON=$(kubectl -n "$NS" get httproute traffic-director -o json 2>/dev/null)
if [ -z "$JSON" ]; then
  echo "❌ HTTPRoute traffic-director does not exist in $NS"
  exit 1
fi
if ! echo "$JSON" | jq -e '
  def auto: any(.matches[]?; ((.path.value // "") == "/auto"));
  def hdr: any(.matches[]?; ((.headers // []) | length) > 0);
  [.spec.rules | to_entries[] | select(.value | auto)] as $r
  | [$r[] | select(.value | hdr) | .key] as $h
  | [$r[] | select((.value | hdr) | not) | .key] as $c
  | ($h | length) > 0 and ($c | length) > 0
    and (($c | min) > ($h | max))
    and ([$r[] | select((.value | hdr) | not) | .value.backendRefs[]? | select(.name == "web-desktop" and .port == 80)] | length > 0)
' >/dev/null 2>&1; then
  echo "❌ The /auto catch-all rule must target web-desktop and come after the mobile header rule"
  exit 1
fi
echo "✅ The /auto catch-all rule targets web-desktop and comes after the header rule"
exit 0
