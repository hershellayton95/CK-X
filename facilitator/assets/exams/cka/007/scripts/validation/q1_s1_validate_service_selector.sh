#!/bin/bash
if ! kubectl get svc web -n drill-variation-a >/dev/null 2>&1; then
  echo "Service web not found in drill-variation-a"
  exit 1
fi
if ! kubectl get svc web -n drill-variation-a -o json 2>/dev/null | jq -e '.spec.selector == {"app.kubernetes.io/name":"web"}' >/dev/null; then
  SEL=$(kubectl get svc web -n drill-variation-a -o jsonpath='{.spec.selector}' 2>/dev/null)
  echo "Service selector is '${SEL:-none}', expected exactly {app.kubernetes.io/name: web}"
  exit 1
fi
echo "Service web selector matches the web pod labels"
exit 0
