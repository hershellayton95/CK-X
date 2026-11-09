#!/bin/bash
NS=project-r500
JSON=$(kubectl -n "$NS" get httproute traffic-director -o json 2>/dev/null)
if [ -z "$JSON" ]; then
  echo "❌ HTTPRoute traffic-director does not exist in $NS"
  exit 1
fi
if ! echo "$JSON" | jq -e '
  def autoheader: [.spec.rules[] | select(any(.matches[]?;
    ((.path.value // "") == "/auto") and
    (((.headers // []) | any(.[];
      (((.name // "") | ascii_downcase) == "user-agent") and
      ((.type // "") == "Exact") and
      ((.value // "") == "mobile"))))))];
  (autoheader | length) >= 1 and
  (autoheader | all(.[]; ((.backendRefs // []) | any(.[]; .name == "web-mobile" and .port == 80))))
' >/dev/null 2>&1; then
  echo "❌ /auto does not have an exact User-Agent: mobile rule targeting web-mobile"
  exit 1
fi
echo "✅ The /auto mobile rule matches User-Agent exactly and targets web-mobile"
exit 0
