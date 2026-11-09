#!/bin/bash
VAL=$(kubectl -n api-gateway-prod get hpa api-gateway \
  -o jsonpath='{.spec.scaleTargetRef.kind}|{.spec.scaleTargetRef.name}|{.spec.minReplicas}|{.spec.maxReplicas}|{.spec.metrics[0].type}|{.spec.metrics[0].resource.name}|{.spec.metrics[0].resource.target.type}|{.spec.metrics[0].resource.target.averageUtilization}' 2>/dev/null)
EXPECTED='Deployment|api-gateway|2|6|Resource|cpu|Utilization|50'
if [ "$VAL" != "$EXPECTED" ]; then
  echo "❌ Prod HPA is incorrect"
  echo "Found:    ${VAL:-none}"
  echo "Expected: $EXPECTED"
  exit 1
fi
echo "✅ Prod HPA targets api-gateway with min 2, max 6 and 50% CPU"
exit 0
