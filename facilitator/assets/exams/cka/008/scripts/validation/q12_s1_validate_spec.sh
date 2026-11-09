#!/bin/bash
NS=project-tiger
if ! kubectl -n "$NS" get deployment deploy-important >/dev/null 2>&1; then
  echo "❌ Deployment deploy-important does not exist in $NS"
  exit 1
fi
if ! kubectl -n "$NS" get deployment deploy-important -o json 2>/dev/null | jq -e '
  def matches_id:
    ((.matchLabels.id // "") == "very-important") or
    ([.matchExpressions[]? | select(.key == "id") | .values[]?] | index("very-important") != null);
  .spec.replicas == 3 and
  .metadata.labels.id == "very-important" and
  .spec.template.metadata.labels.id == "very-important" and
  (.spec.template.spec.containers | any(.[]; .name == "container" and .image == "nginx:1-alpine")) and
  (.spec.template.spec.containers | any(.[]; .name == "container2" and .image == "registry.k8s.io/pause:3.10")) and
  (
    ((.spec.template.spec.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution // []) |
      any(.[]; .topologyKey == "kubernetes.io/hostname" and (.labelSelector | matches_id)))
    or
    ((.spec.template.spec.topologySpreadConstraints // []) |
      any(.[]; .topologyKey == "kubernetes.io/hostname" and (.labelSelector | matches_id)))
  )
' >/dev/null 2>&1; then
  echo "❌ Deployment spec is missing required labels, replicas, containers or hostname scheduling rule"
  exit 1
fi
echo "✅ Deployment deploy-important has the required spec"
exit 0
