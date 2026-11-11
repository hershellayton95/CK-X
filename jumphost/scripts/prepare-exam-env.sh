#!/bin/bash
exec >> /proc/1/fd/1 2>&1

# SSH sessions do not inherit the container environment. start-jumphost writes
# the session's cluster name, facilitator URL and internal token to this file.
if [ -f /etc/ckx-env ]; then
  . /etc/ckx-env
fi

CLUSTER_NAME=${CLUSTER_NAME:-cluster}

# Log function with timestamp
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Set defaults
NUMBER_OF_NODES=${1:-1}
EXAM_ID=${2:-""}

echo "Exam ID: $EXAM_ID"
echo "Number of nodes: $NUMBER_OF_NODES"

#check docker is running
if ! docker info > /dev/null 2>&1; then
  log "Docker is not running"
  log "Attempting to start docker"
  dockerd &
  sleep 5
  #check docker is running 3 times with 5 second interval
  for i in {1..3}; do
    if docker info > /dev/null 2>&1; then
      log "Docker started successfully"
      break
    fi
    log "Docker failed to start, retrying..."
    sleep 5
  done
fi

log "Starting exam environment preparation with $NUMBER_OF_NODES node(s)"

# Validate input
if ! [[ "$NUMBER_OF_NODES" =~ ^[0-9]+$ ]]; then
  log "ERROR: Number of nodes must be a positive integer"
  exit 1
fi

# Setup kind cluster
if ! ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null candidate@k8s-api-server "env-setup $NUMBER_OF_NODES $CLUSTER_NAME"; then
  log "ERROR: cluster setup failed for $CLUSTER_NAME"
  exit 1
fi

#Pull assets from URL
# In multisession mode the assets endpoint requires a session cookie or the
# shared internal token (the jumphost has no candidate session).
FACILITATOR_URL=${FACILITATOR_URL:-http://facilitator:3000}
if ! curl -fsS -H "X-Internal-Token: ${INTERNAL_TOKEN:-}" "$FACILITATOR_URL/api/v1/exams/$EXAM_ID/assets" -o assets.tar.gz; then
  log "ERROR: failed to download exam assets from $FACILITATOR_URL"
  exit 1
fi

mkdir -p /tmp/exam-assets
#Unzip assets
tar -xzvf assets.tar.gz -C /tmp/exam-assets    

#Remove assets.tar.gz
rm assets.tar.gz

#make every file in /tmp/exam-assets executable
find /tmp/exam-assets -type f -exec chmod +x {} \;

echo "Exam assets downloaded and prepared successfully" 

export KUBECONFIG=/home/candidate/.kube/kubeconfig

sleep 5

#wait till api-server is ready (bounded so a broken cluster fails the exam
# instead of leaving it in PREPARING forever)
API_WAIT_COUNT=0
API_WAIT_MAX=120
while ! kubectl get nodes > /dev/null 2>&1; do
  API_WAIT_COUNT=$((API_WAIT_COUNT+1))
  if [ "$API_WAIT_COUNT" -ge "$API_WAIT_MAX" ]; then
    log "ERROR: API server did not become ready after $API_WAIT_MAX attempts"
    exit 1
  fi
  log "API server is not ready, retrying... (attempt $API_WAIT_COUNT)"
  sleep 5
done

echo "API server is ready"

#Run setup scripts
for script in /tmp/exam-assets/scripts/setup/q*_setup.sh; do $script; done

log "Exam environment preparation completed successfully"
exit 0 