#!/bin/bash
GEN=$(kubectl get deploy web -n drill-variation-a -o jsonpath='{.metadata.generation}' 2>/dev/null)
if [ "$GEN" != "1" ]; then
  echo "Deployment web generation is '${GEN:-none}', expected 1 - the Deployment must not be modified (fix the Service instead)"
  exit 1
fi
if [ ! -s /tmp/exam/variation_a_pods.txt ]; then
  echo "Recorded pod identities file /tmp/exam/variation_a_pods.txt is missing - cannot verify pods were untouched"
  exit 1
fi
NOW=$(kubectl get pods -n drill-variation-a -l app.kubernetes.io/name=web -o jsonpath='{range .items[*]}{.metadata.uid}{"\n"}{end}' 2>/dev/null | sort)
if [ "$(echo "$NOW" | grep -c .)" != "3" ]; then
  echo "expected 3 web pods, found: $(echo "$NOW" | grep -c .)"
  exit 1
fi
if [ "$NOW" != "$(cat /tmp/exam/variation_a_pods.txt)" ]; then
  echo "web pod identities changed - the running pods must not be restarted or replaced"
  exit 1
fi
echo "Deployment generation unchanged and all 3 original web pods still running"
exit 0
