#!/bin/bash
COREFILE=$(kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}' 2>/dev/null)
if ! echo "$COREFILE" | grep -q 'custom-domain'; then
  echo "❌ The CoreDNS configuration has not been updated with custom-domain"
  exit 1
fi
DESIRED=$(kubectl -n kube-system get deployment coredns -o jsonpath='{.spec.replicas}' 2>/dev/null)
READY=$(kubectl -n kube-system get deployment coredns -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [ "${READY:-0}" -lt "${DESIRED:-1}" ]; then
  echo "❌ CoreDNS has ${READY:-0} ready replicas out of ${DESIRED:-1}"
  exit 1
fi
if ! kubectl -n kube-system rollout status deployment/coredns --timeout=15s >/dev/null 2>&1; then
  echo "❌ CoreDNS rollout is not complete"
  exit 1
fi
echo "✅ CoreDNS is rolled out and ready"
exit 0
