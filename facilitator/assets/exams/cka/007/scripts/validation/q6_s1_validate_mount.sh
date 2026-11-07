#!/bin/bash
J=$(kubectl get pod secret-1401 -n admin1401 -o json 2>/dev/null) || { echo "Pod secret-1401 not found in admin1401"; exit 1; }
if ! echo "$J" | jq -e '.spec.volumes[] | select(.name=="secret-volume") | select(.secret.secretName=="dotfile-secret")' >/dev/null; then
  echo "volume secret-volume must mount secret dotfile-secret"
  exit 1
fi
if ! echo "$J" | jq -e '.spec.containers[] | select(.name=="secret-admin") | .volumeMounts[] | select(.name=="secret-volume") | select(.mountPath=="/etc/secret-volume") | select(.readOnly==true)' >/dev/null; then
  echo "container secret-admin must mount secret-volume read-only at /etc/secret-volume"
  exit 1
fi
echo "Secret mounted read-only at /etc/secret-volume"
exit 0
