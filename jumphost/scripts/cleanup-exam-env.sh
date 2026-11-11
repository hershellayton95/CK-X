#!/bin/bash
exec >> /proc/1/fd/1 2>&1

# SSH sessions do not inherit the container environment. start-jumphost writes
# the session's cluster name, facilitator URL and internal token to this file.
if [ -f /etc/ckx-env ]; then
  . /etc/ckx-env
fi

CLUSTER_NAME=${CLUSTER_NAME:-cluster}

# cleanup-exam-env.sh
# 
# This script cleans up the exam environment on the jumphost.
# It removes all resources created during the exam to prepare for a new exam.
#
# Usage: cleanup-exam-env.sh
#
# Example: cleanup-exam-env.sh

# Log function with timestamp
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting exam environment cleanup"
log "Cleaning up cluster $CLUSTER_NAME"
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null candidate@k8s-api-server "env-cleanup $CLUSTER_NAME"

# Clean up Docker resources created on the jumphost's own Docker daemon.
# The jumphost runs its own dockerd and each session gets a dedicated container,
# so this never touches the host daemon or another candidate's environment.
# Image pruning is intentionally omitted: it was global, slow, and the whole
# container (with its daemon state) is destroyed with the session stack.
if docker info > /dev/null 2>&1; then
  log "Removing containers, networks and volumes left by the exam"
  docker ps -aq | xargs -r docker rm -f > /dev/null 2>&1 || true
  docker network ls -q --filter type=custom | xargs -r docker network rm > /dev/null 2>&1 || true
  docker volume ls -q | xargs -r docker volume rm -f > /dev/null 2>&1 || true
else
  log "Docker is not running on the jumphost, skipping container cleanup"
fi

# Remove the exam environment directory
log "Removing exam environment directory"
rm -rf /tmp/exam-env
rm -rf /tmp/exam

# Remove the exam assets directory
log "Removing exam assets directory"
rm -rf /tmp/exam-assets

log "Exam environment cleanup completed successfully"
exit 0 