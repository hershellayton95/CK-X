#!/bin/sh

# ===============================================================================
#   KIND Cluster Setup Entrypoint Script
#   Purpose: Initialize Docker and create Kind cluster
# ===============================================================================

echo "$(date '+%Y-%m-%d %H:%M:%S') | ===== INITIALIZATION STARTED ====="
echo "$(date '+%Y-%m-%d %H:%M:%S') | Executing container startup script..."

# Execute current entrypoint script
if [ -f /usr/local/bin/startup.sh ]; then
    sh /usr/local/bin/startup.sh &
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') | [INFO] Default startup script not found at /usr/local/bin/startup.sh"
fi

# ===============================================================================
#   Docker Readiness Check
# ===============================================================================

echo "$(date '+%Y-%m-%d %H:%M:%S') | Checking Docker service status..."
DOCKER_CHECK_COUNT=0

# Wait for docker to be ready (bounded so a broken dind fails the container
# instead of leaving the session waiting forever)
while ! docker ps; do   
    DOCKER_CHECK_COUNT=$((DOCKER_CHECK_COUNT+1))
    if [ "$DOCKER_CHECK_COUNT" -ge 60 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') | [ERROR] Docker did not start after 60 attempts"
        exit 1
    fi
    echo "$(date '+%Y-%m-%d %H:%M:%S') | [WAITING] Docker service not ready yet... (attempt $DOCKER_CHECK_COUNT)"
    sleep 5
done

echo "$(date '+%Y-%m-%d %H:%M:%S') | [SUCCESS] Docker service is ready and operational"

#pull kindest/node image
# docker pull kindest/node:$KIND_DEFAULT_VERSION

#add user for ssh access
adduser -S -D -H -s /sbin/nologin -G sshd sshd

#start ssh service
/usr/sbin/sshd -D &

#install k3d
echo "$(date '+%Y-%m-%d %H:%M:%S') | [INFO] Installing k3d"
TAG=v5.8.3 bash /usr/local/bin/k3d-install.sh

sleep 10
touch /ready

# Keep container running
tail -f /dev/null