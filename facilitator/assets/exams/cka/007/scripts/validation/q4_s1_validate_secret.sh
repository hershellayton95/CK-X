#!/bin/bash
T=$(kubectl get secret private-reg-cred -n image-security -o jsonpath='{.type}' 2>/dev/null)
if [ "$T" != "kubernetes.io/dockerconfigjson" ]; then
  echo "secret type is '${T:-none}', expected kubernetes.io/dockerconfigjson (use kubectl create secret docker-registry)"
  exit 1
fi
DCJ=$(kubectl get secret private-reg-cred -n image-security -o jsonpath='{.data.\.dockerconfigjson}' 2>/dev/null)
if [ -z "$DCJ" ]; then
  echo "secret has no .dockerconfigjson entry"
  exit 1
fi
if ! echo "$DCJ" | base64 -d | jq -e '.auths["myprivateregistry.com:5000"] | .username=="dock_user" and .password=="dock_password" and .email=="dock_user@myprivateregistry.com"' >/dev/null 2>&1; then
  echo "dockerconfigjson must contain myprivateregistry.com:5000 with dock_user / dock_password / dock_user@myprivateregistry.com"
  exit 1
fi
echo "Secret private-reg-cred has the required registry credentials"
exit 0
