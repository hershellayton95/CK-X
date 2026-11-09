#!/bin/bash
NS=project-tiger
if ! kubectl -n "$NS" get daemonset ds-important >/dev/null 2>&1; then
  echo "❌ DaemonSet ds-important does not exist in $NS"
  exit 1
fi
if ! kubectl -n "$NS" get daemonset ds-important -o json 2>/dev/null | jq -e '
  .metadata.labels.id == "ds-important" and
  .metadata.labels.uuid == "18426a0b-5f59-4e10-923f-c0e078e82462" and
  .spec.template.metadata.labels.id == "ds-important" and
  .spec.template.metadata.labels.uuid == "18426a0b-5f59-4e10-923f-c0e078e82462" and
  (.spec.template.spec.containers | any(.[];
    .image == "httpd:2-alpine" and
    .resources.requests.cpu == "10m" and
    .resources.requests.memory == "10Mi")) and
  (.spec.template.spec.tolerations | any(.[];
    .key == "node-role.kubernetes.io/control-plane" and .effect == "NoSchedule"))
' >/dev/null 2>&1; then
  echo "❌ DaemonSet spec is missing required labels, image, requests or control-plane toleration"
  exit 1
fi
echo "✅ DaemonSet ds-important has the required spec"
exit 0
