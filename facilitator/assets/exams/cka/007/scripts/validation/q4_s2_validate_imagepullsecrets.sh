#!/bin/bash
if ! kubectl get deploy web -n image-security -o json 2>/dev/null | jq -e '[.spec.template.spec.imagePullSecrets[]? | select(.name=="private-reg-cred")] | length == 1' >/dev/null; then
  echo "Deployment web does not reference imagePullSecret private-reg-cred"
  exit 1
fi
echo "Deployment web uses imagePullSecret private-reg-cred"
exit 0
