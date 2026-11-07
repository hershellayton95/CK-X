#!/bin/bash
J=$(kubectl get netpol cyan-np -n cyan-ns -o json 2>/dev/null) || { echo "NetworkPolicy cyan-np not found"; exit 1; }
N=$(echo "$J" | jq -r '[.spec.ingress[]?] | length')
if [ "${N:-0}" -ne 1 ]; then
  echo "expected exactly 1 ingress rule, found $N - a broader extra rule would let other pods in"
  exit 1
fi
if ! echo "$J" | jq -e '(.spec.ingress[0].from | length) == 1' >/dev/null; then
  echo "ingress[0].from must contain exactly one entry - separate namespaceSelector and podSelector entries are OR-combined, not AND"
  exit 1
fi
if ! echo "$J" | jq -e '.spec.ingress[0].from[0].podSelector.matchLabels.client == "white"' >/dev/null; then
  echo "from must be constrained with podSelector client=white in the SAME entry as the namespaceSelector"
  exit 1
fi
if ! echo "$J" | jq -e '
    ((.spec.ingress[0].from[0].namespaceSelector | not) or
     .spec.ingress[0].from[0].namespaceSelector.matchLabels["kubernetes.io/metadata.name"] == "cyan-ns")' >/dev/null; then
  echo "namespaceSelector (if present) must restrict to namespace cyan-ns"
  exit 1
fi
echo "Ingress from is constrained to client=white pods in cyan-ns"
exit 0
