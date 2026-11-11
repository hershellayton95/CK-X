# CK-X Simulator: Development Setup Guide

This document provides step-by-step instructions for setting up and running the CK-X Simulator locally for development purposes.

## Prerequisites

### System Requirements
- **Operating System**: Linux, macOS, or Windows 10/11 with WSL2
- **CPU**: 4+ cores recommended (minimum 2 cores)
- **RAM**: 8GB minimum, 16GB recommended
- **Storage**: 20GB free space

### Required Software
- **Docker**: v20.10.0 or newer
- **Docker Compose**: v2.0.0 or newer

## Installation Steps

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/ck-x-simulator.git
cd ck-x-simulator
```

### 2. Configure the Environment

Review the `docker-compose.yaml` file to understand the service configuration. Key services include:

- **remote-desktop**: VNC server (Ubuntu 24.04 + XFCE, served over noVNC)
- **webapp**: Web Application frontend
- **nginx**: Reverse proxy (only service exposed to users)
- **jumphost**: SSH access host
- **remote-terminal**: Remote terminal service
- **k8s-api-server**: k3d/k3s cluster host (container name `kind-cluster` for compatibility)
- **redis**: Redis database for Facilitator
- **facilitator**: Backend service

### 3. Start the Services

```bash
# Build and start all services
docker compose up -d --build
```

This command builds and starts all services defined in `docker-compose.yaml`.
Images are tagged `ckx/<service>:${SESSION_IMAGE_TAG:-dev}`.

## Accessing the Application

### 1. Web Interface

Once all services are running, access the web interface via Nginx:

```
http://localhost:30080
```

### 2. VNC Remote Desktop

The VNC server is not directly exposed outside the container network. To access it:

1. The web interface proxies VNC connections through Nginx
2. Single-environment default VNC password: `bakku-the-wizard` (configured in `docker-compose.yaml`)
3. Multisession: each session gets a random VNC password, returned only to its browser via `/api/session-info`
4. VNC resolution: 1280x800

### 3. SSH Access

SSH access is provided through the jumphost service:

- **Hostname**: follows the certification - `cka9999` for CKA, `ckad9999` for
  CKAD, `cks9999` for CKS, `kcna9999`, `kcsa9999`, `playground9999`, and
  `other9999`. Every name is a network alias of the same jumphost, so older lab
  text that says `ckad9999` still works.
- **Username**: candidate
- **Password**: `password` in single-environment mode; random per session in multisession mode (never sent to the browser)

The SSH service is not directly exposed outside the container network and is accessed through the webapp.

## Service Details

### 1. Remote Desktop (VNC)

```yaml
# From docker-compose.yaml
remote-desktop:
  image: ckx/ck-x-remote-desktop:${SESSION_IMAGE_TAG:-dev}
  hostname: terminal
  expose:
    - "5901"  # VNC port (internal only)
    - "6901"  # Web VNC port (internal only)
  environment:
    - VNC_PW=bakku-the-wizard
    - VNC_PASSWORD=bakku-the-wizard
    - VNC_VIEW_ONLY=false
    - VNC_RESOLUTION=1280x800
```

The remote desktop provides a graphical interface for the exam environment.

### 2. Web Application

```yaml
# From docker-compose.yaml
webapp:
  image: ckx/ck-x-webapp:${SESSION_IMAGE_TAG:-dev}
  expose:
    - "3000"  # Only exposed to internal network
  environment:
    - VNC_SERVICE_HOST=remote-desktop
    - VNC_SERVICE_PORT=6901
    - VNC_PASSWORD=bakku-the-wizard
    - SSH_HOST=remote-terminal
    - SSH_PORT=22
    - SSH_USER=candidate
    - SSH_PASSWORD=password
```

The web application serves as the frontend interface for the simulator.

### 3. Nginx (Reverse Proxy)

```yaml
# From docker-compose.yaml
nginx:
  image: ckx/ck-x-nginx:${SESSION_IMAGE_TAG:-dev}
  ports:
    - "30080:80"  # Expose Nginx on port 30080
```

Nginx is the only service directly exposed to users and handles routing to internal services.

### 4. Kubernetes Cluster

```yaml
# From docker-compose.yaml
k8s-api-server:
  image: ckx/ck-x-k8s-api-server:${SESSION_IMAGE_TAG:-dev}
  container_name: kind-cluster
  hostname: k8s-api-server
  privileged: true  # Required for running k3d/k3s inside the container
  expose:
    - "6443"
    - "22"
  volumes:
    - kube-config:/home/candidate/.kube  # Shared volume for Kubernetes config
```

The Kubernetes cluster runs in a k3d/k3s container (container name `kind-cluster`
for compatibility) with a shared kube-config volume.

### 5. Facilitator Service

```yaml
# From docker-compose.yaml
facilitator:
  image: ckx/ck-x-facilitator:${SESSION_IMAGE_TAG:-dev}
  hostname: facilitator
  expose:
    - "3000"          # internal only; nginx proxies /facilitator/api/
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock   # per-session stacks
  environment:
    - PORT=3000
    - NODE_ENV=prod
    - SSH_HOST=jumphost
    - SSH_PORT=22
    - SSH_USERNAME=candidate
    - LOG_LEVEL=info
    - REDIS_HOST=redis
    - REDIS_PORT=6379
    - MULTISESSION_ENABLED=${MULTISESSION_ENABLED:-false}
    - MAX_SESSIONS=${MAX_SESSIONS:-3}
    - SESSION_SECRET=${SESSION_SECRET:-}
    - INTERNAL_TOKEN=${INTERNAL_TOKEN:-}
```

The facilitator handles backend operations and, when multisession is enabled,
spawns one Docker Compose stack per session. With `NODE_ENV=prod` it refuses to
start if `SESSION_SECRET` or `INTERNAL_TOKEN` is missing or too short.

## Development Workflow

### 1. Modifying Services

To modify a service, edit its corresponding directory and then rebuild:

```bash
# Edit files in the respective service directory
# Then rebuild and restart the service
docker compose up --build <service-name>
```

### 2. Inspecting Logs

```bash
# View logs for all services
docker compose logs

# View logs for a specific service
docker compose logs <service-name>

# Follow logs
docker compose logs -f <service-name>
```

### 3. Accessing Containers

```bash
# Get shell access to a container
docker compose exec <service-name> bash

# Examples:
docker compose exec webapp bash
docker compose exec facilitator bash
docker compose exec k8s-api-server bash
```

## Multisession Development

Prerequisites: Docker CLI + compose plugin available to the facilitator, the host
Docker socket, and images built with the root compose.

```bash
cp .env.example .env
# set MULTISESSION_ENABLED=true, SESSION_SECRET (>= 32 chars),
# INTERNAL_TOKEN (>= 16 chars); ADMIN_TOKEN is optional

docker compose up -d --build
docker compose logs -f facilitator
```

Inspect live sessions and in-process metrics:

```bash
curl -H "X-Admin-Token: $ADMIN_TOKEN" \
  http://localhost:30080/facilitator/api/v1/sessions
```

Inspect per-session resources:

```bash
docker ps -a --filter label=ckx.managed=true \
  --format '{{.Names}}\t{{.Label "ckx.session"}}\t{{.Status}}'
docker network ls --filter label=ckx.managed=true
docker volume ls --filter label=ckx.managed=true
```

Notes:

- The root compose sets `NODE_ENV=prod`, so the facilitator exits at startup if
  `SESSION_SECRET`/`INTERNAL_TOKEN` are missing or too short.
- A local `npm run dev` facilitator needs Redis, Docker socket access, the k3d
  images, and `SESSION_COMPOSE_FILE` (or the repo-relative
  `docker-compose.session.yaml`).
- Only nginx is published (`:30080`). Session desktops/terminals are reachable
  only through the webapp/nginx.
- Defaults: 30 min idle, 8 h hard TTL, 60 s sweep. Use short values for reaper
  testing; the exam page heartbeats every 5 min.

## Troubleshooting

### 1. Container Startup Issues

If containers fail to start, check the logs:

```bash
docker compose logs <service-name>
```

### 2. VNC Connection Issues

```bash
# Check if VNC server is running
docker compose exec remote-desktop ps aux | grep vnc

# Restart VNC service
docker compose restart remote-desktop
```

### 3. Kubernetes Cluster Issues

```bash
# Check cluster status
docker compose exec k8s-api-server kubectl cluster-info

# Restart the cluster
docker compose restart k8s-api-server
```

### 4. Resource Constraints

If your system cannot handle the resource requirements, adjust the limits in `docker-compose.yaml` (control plane) and `facilitator/docker-compose.session.yaml` (per-session data plane):

```yaml
deploy:
  resources:
    limits:
      cpus: '1'  # Reduce CPU allocation
      memory: 1G  # Reduce memory allocation
```

## Network Architecture

Control-plane services are connected through the `ckx-network` bridge network:

```yaml
networks:
  ckx-network:
    name: ckx-network
    driver: bridge
```

Multisession adds two network layers:

- `ckx-sessions` (shared): `webapp` and every session's `remote-desktop` /
  `remote-terminal`, so the webapp proxies each browser to the right container.
- `ckx-<session-id>-net` (per session): `k8s-api-server`, `jumphost`,
  `remote-desktop`, `remote-terminal`, and the facilitator (attached at runtime
  so setup/grading can reach the jumphost). Joining the desktop/terminal to the
  session network keeps the single-env SSH flow (`ssh candidate@<category>9999`,
  e.g. `cka9999` for a CKA lab) working.

Services inside one session talk to each other by service name
(`k8s-api-server`, `jumphost`, `remote-desktop`, `remote-terminal`). Those names
are not global: each session has its own copies.

## Volume Management

```yaml
volumes:
  kube-config:  # Shared kubeconfig for the single-environment stack
```

Redis persistence uses its AOF file inside the `redis` container; there is no
named Redis volume. Multisession adds one kubeconfig volume per session,
`ckx-<session-id>-kube`, removed with the session stack.

## Reference Links

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [k3d Documentation](https://k3d.io/)
- [Multisession operations](multisession.md)
- [VNC Documentation](https://www.realvnc.com/en/connect/docs/) 