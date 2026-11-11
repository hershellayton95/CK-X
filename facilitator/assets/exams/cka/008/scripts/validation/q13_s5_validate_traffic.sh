#!/bin/bash
BASE=http://r500.gateway:30080

fetch() {
  curl -sS -m 5 "$@" 2>/dev/null | tr -d '\r\n'
}

# Give the controller a moment to program the route.
for attempt in $(seq 1 10); do
  D=$(fetch "$BASE/desktop")
  [ "$D" = "web-desktop" ] && break
  sleep 2
done

D=$(fetch "$BASE/desktop")
M=$(fetch "$BASE/mobile")
AM=$(fetch -H 'User-Agent: mobile' "$BASE/auto")
AD=$(fetch -H 'User-Agent: curl' "$BASE/auto")

[ "$D" = "web-desktop" ] || { echo "❌ /desktop returned '${D:-nothing}', expected 'web-desktop'"; exit 1; }
[ "$M" = "web-mobile" ] || { echo "❌ /mobile returned '${M:-nothing}', expected 'web-mobile'"; exit 1; }
[ "$AM" = "web-mobile" ] || { echo "❌ /auto with User-Agent: mobile returned '${AM:-nothing}', expected 'web-mobile'"; exit 1; }
[ "$AD" = "web-desktop" ] || { echo "❌ /auto without the mobile User-Agent returned '${AD:-nothing}', expected 'web-desktop'"; exit 1; }

echo "✅ Real traffic through r500.gateway:30080 follows all four routes"
exit 0
