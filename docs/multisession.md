# Multisession

Status: **complete** (M0: feature flag + config; M1: sessions + ownership;
M2: per-session environment provider; M3: per-session jumphost/cluster, verified
with two concurrent real labs; M4: per-session desktop/terminal routing in the
shared webapp; M5: session-aware dashboard, verified with a headless browser
suite; M6: idle/hard expiry, reconciliation, limits, metrics and admin session
listing; M7: production secret fail-fast, ownership/credential audit, operations
documentation; M8: three concurrent real labs, 30-minute soak, independent
grading, cross-session denial, clean teardown and slot reuse).

CK-X supports two rollouts from the same images:

- **single-environment** (default): one Kubernetes cluster, one desktop, one
  terminal, and the global `current-exam-id` exam pointer;
- **multisession**: 2–5 candidates concurrently, each with a signed session
  cookie and its own complete data plane (cluster, jumphost, desktop, terminal).

Both share the same control plane (nginx, webapp, facilitator, Redis). The
multisession path is enabled with `MULTISESSION_ENABLED=true`; see
[Rollback](#rollback) for returning to the single-environment behavior.

## Architecture

```
browser :30080
   |
 nginx --> webapp ------> facilitator ------> Redis (sessions + exam data)
   |          |                |
   |          |                +--> Docker socket --> ckx-<sid>-* compose stack
   |          |
   |          +--> shared ckx-sessions network --> per-session desktop/terminal
   |
   +--> /facilitator/api/* proxied to the facilitator
```

- **Control plane** (one per deployment): `nginx`, `webapp`, `facilitator`,
  `redis`. Only nginx is published, at `:30080`.
- **Data plane** (one per session): Docker Compose project `ckx-<session-id>`
  with `k8s-api-server`, `jumphost`, `remote-desktop`, `remote-terminal`, a
  private network `ckx-<session-id>-net`, and a kubeconfig volume
  `ckx-<session-id>-kube`. The k3d cluster is
  `ckx-<first 12 hex of the session id>`; its kubeconfig context is
  `k3d-ckx-<first 12 hex of the session id>`.
- **Identity**: `POST /api/v1/exams` creates a Redis session record and sets an
  HMAC-signed, HttpOnly `ckx_session` cookie. Every `/exams/:examId/*` route
  requires both a live session and ownership of that exam.
- **Browser routing**: the webapp forwards the cookie to
  `GET /api/v1/sessions/me` (short cache), then proxies `/vnc-proxy`,
  `/websockify`, and the `/ssh` socket to that session's desktop/terminal over
  the shared `ckx-sessions` network. Without a session it uses the static
  single-environment targets.
- **Teardown**: terminate deletes the session and answers before destroying the
  stack (network removal resets in-flight sockets). The reaper and startup
  reconciliation remove anything left behind.

Design and rollout plan live outside the repo for now:
- architecture, file-level change map, verification steps: `multisession-plan.md`
- milestone checklist and resume notes: `multisession-todo.md`

## Feature flag

Multisession is disabled by default:

```bash
MULTISESSION_ENABLED=false
```

With the flag off, behavior is identical to the single-environment release.
Roll back by setting it back to `false`.

## Environment variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `MULTISESSION_ENABLED` | `false` | Enables the session-aware code paths. |
| `MAX_SESSIONS` | `3` | Concurrent session cap; new sessions get `429` when full. |
| `SESSION_SECRET` | — | HMAC secret for signed session cookies. Required when enabled; production refuses to start if missing or shorter than 32 characters. |
| `INTERNAL_TOKEN` | — | Shared secret for service-to-service calls (per-session jumphost asset download). Required when enabled; production refuses to start if missing or shorter than 16 characters. |
| `FACILITATOR_URL` | `http://facilitator:3000` | Asset URL used by per-session jumphosts. |
| `SESSION_IMAGE_TAG` | `dev` | Image tag built by the root compose and used by per-session stacks. |
| `SESSION_CONTROL_NETWORK` | `ckx-sessions` | Shared network the webapp and every session desktop/terminal join, so the webapp routes each browser without runtime network attach/detach. |
| `SESSION_TTL_SECONDS` | `28800` | Hard session deadline. The Redis record and session cookie never outlive it. |
| `SESSION_IDLE_SECONDS` | `1800` | Reap a session with no API/heartbeat activity for this long. `0` disables idle expiry (hard TTL still applies). |
| `SESSION_SWEEP_INTERVAL_SECONDS` | `60` | Reaper cadence for idle/hard-expired sessions and orphan environments. |
| `ADMIN_TOKEN` | `INTERNAL_TOKEN` | Bearer token for `GET /api/v1/sessions`. Falls back to `INTERNAL_TOKEN` when empty. |
| `EXAM_DATA_TTL_SECONDS` | `28800` | Redis TTL for exam info/status/result/MCQ answers (8 h). |
| `ENV_PROVIDER` | `docker-compose` | Environment provider implementation. |

Copy `.env.example` to `.env` and fill in the secrets before enabling.

## Prerequisites

The facilitator provisions one Docker Compose stack per candidate:

- the host Docker socket mounted into the facilitator
  (`/var/run/docker.sock`);
- the facilitator image includes the Docker CLI and compose plugin;
- all images built by the root compose with the same `SESSION_IMAGE_TAG`
  (`docker compose build`, default tag `dev`).

Each stack runs a nested k3d/k3s cluster inside its own `k8s-api-server`
container. The host kernel therefore needs the modules k3s networking and
kube-router use (`vxlan`, `xt_comment`, `xt_multiport`, `xt_addrtype`,
`br_netfilter`, conntrack/NAT modules). `env-setup` falls back to the flannel
`host-gw` backend when `vxlan` is unavailable, but the netfilter modules are
still required. A kernel upgraded without a reboot usually has no matching
modules in `/lib/modules`; boot into the installed kernel before running
cluster labs.

The facilitator currently runs as root inside its container to access the
Docker socket. This is an MVP trade-off; a follow-up hardening change replaces
it with a restricted socket proxy.

## Capacity

Budget roughly **5 GB RAM and 2.5 CPU per concurrent session** (Kubernetes
cluster ~2–4 GB, remote desktop ~1.5–2 GB, jumphost ~0.5 GB).

- 3 sessions: ~16 GB RAM, 8 vCPU
- 5 sessions: ~26–30 GB RAM, 12–16 vCPU

Measured during the M8 soak (12-core / 24 GB host, 3 concurrent labs, 30 min):

- all 12 session containers: ~3.8 GB RSS peak and <1 CPU total while the
  clusters were idle;
- host: ~8.4 GB used peak, 15.3 GB still available;
- three clusters reached `READY` in ~95 s.

That figure is idle traffic without live VNC streams; keep the 5 GB/session
planning budget for real candidates. Five sessions on a 24 GB host is not
recommended; use 32 GB+ and 12–16 vCPUs.

Session creation is refused with `429 Too Many Requests` above `MAX_SESSIONS`.

`POST /exams/:examId/terminate` answers first and destroys the session stack in
the background. Tearing down the stack removes the Docker network the
facilitator is attached to, which resets any HTTP connection still carrying the
response, so the reply has to be sent before teardown starts. Consequences:

- the session and its slot are released immediately; the old stack may still be
  stopping while a new session provisions;
- a teardown failure is only visible in the facilitator log, not in the HTTP
  response; stacks left behind by a crash are removed by reconciliation.

## Session expiry and reconciliation

Each session stores a fixed `expiresAt` (hard TTL) and a `lastSeenAt` that is
refreshed by any cookie-authenticated API call (writes are throttled to once per
minute). The exam page also sends a 5-minute heartbeat so a candidate working
only in the desktop does not look idle.

Every `SESSION_SWEEP_INTERVAL_SECONDS` (default 60 s) the facilitator:

1. reaps sessions past `expiresAt` or idle for `SESSION_IDLE_SECONDS` (default
   30 min): destroys the per-session stack, deletes the exam data, and removes
   the Redis record so the slot is reusable;
2. reconciles Docker: any `ckx.managed=true` stack whose `ckx.session` label has
   no live Redis record is removed. This also retries stacks whose teardown
   failed during reaping;
3. refreshes the active-session gauge.

The same reconciliation runs once at facilitator start, so killing the
facilitator mid-session does not leak containers, networks, volumes, or slots.
Live sessions survive a facilitator restart (their records are in Redis) and
their data planes are kept.

Sweeps are serialized with a Redis lock, so running more than one facilitator
replica cannot double-reap the same session.

## Admin visibility

```bash
curl -H "X-Admin-Token: $ADMIN_TOKEN" http://localhost:30080/facilitator/api/v1/sessions
```

Returns the live sessions (status, exam, lab, timestamps, and a sanitized
environment descriptor without VNC/terminal passwords), the configured caps,
and in-process metrics: sessions created/destroyed/failed/expired, active
sessions, and provision-duration count/average/max. Requests without a valid
token get `401`. `X-Internal-Token` is accepted as an alias.

Lifecycle logs carry `sessionId` (and `examId`/`reason`/`durationMs` where
relevant); passwords and cookies are never logged.

## Operations

Typical enablement:

```bash
cp .env.example .env
# fill SESSION_SECRET, INTERNAL_TOKEN, and optionally ADMIN_TOKEN
openssl rand -hex 32   # use a different value for each secret

docker compose up -d --build
curl http://localhost:30080/health
curl -H "X-Admin-Token: $ADMIN_TOKEN" \
  http://localhost:30080/facilitator/api/v1/sessions
```

Verify per-session resources by label:

```bash
docker ps -a --filter label=ckx.managed=true \
  --format '{{.Names}}\t{{.Label "ckx.session"}}\t{{.Status}}'
docker network ls --filter label=ckx.managed=true
docker volume ls --filter label=ckx.managed=true
```

Useful knobs:

- `MAX_SESSIONS` (default 3): keep within the host RAM/CPU budget.
- `SESSION_IDLE_SECONDS` (default 1800): raise for slow labs; `0` disables idle
  expiry.
- `SESSION_SWEEP_INTERVAL_SECONDS` (default 60): lower for faster reaping, at
  the cost of one `docker ps` per sweep.
- `SESSION_TTL_SECONDS` (default 8 h): hard deadline; Redis and the cookie
  cannot outlive it.
- Per-session CPU/memory limits live in `facilitator/docker-compose.session.yaml`.

Secret rotation:

- Rotating `SESSION_SECRET` invalidates every existing cookie; active candidates
  must return to the dashboard and start again. Rotate during maintenance.
- `INTERNAL_TOKEN` is injected into each stack at spawn time. After rotating it,
  existing jumphosts keep the old value and asset downloads fail; reap/restart
  those sessions (or restart the stack) to pick up the new token.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| `429` on start | `MAX_SESSIONS` reached; inspect the admin endpoint or reap idle sessions. |
| `401` after a facilitator restart | `SESSION_SECRET` changed or unset (random per-process fallback); set a stable secret and restart. |
| `403`/`404` on an exam link | cookie belongs to another session, or the session expired/was reaped. Start from the dashboard in the owning browser. |
| Desktop/terminal `502` | webapp could not resolve the session: check facilitator logs for `sessions/me`, the container names in the admin listing, and that desktop/terminal joined `ckx-sessions`. |
| Lab stuck in `PREPARING` | `docker compose -p ckx-<sid> logs`; the facilitator log has `sessionId`/`examId`; nested k3s needs the kernel modules listed under Prerequisites. |
| Stack remains after terminate | the reaper/reconcile should remove it within `SESSION_SWEEP_INTERVAL_SECONDS`; check `docker ps --filter label=ckx.managed=true`. |
| Asset download fails inside a session | `INTERNAL_TOKEN` mismatch between facilitator and the stack; see secret rotation above. |
| Facilitator exits at startup | production fail-fast: set `SESSION_SECRET` (>= 32 chars) and `INTERNAL_TOKEN` (>= 16 chars) or disable multisession. |

## Rollback

Set the flag back to `false` and rebuild the facilitator:

```bash
MULTISESSION_ENABLED=false
docker compose up -d --build facilitator webapp
```

Flag-off behavior is the original single-environment flow: static
desktop/terminal targets and the global `current-exam-id` exam pointer. Before
rolling back:

1. terminate active labs (or let them finish) so their stacks are cleaned;
2. after the flag is off the reaper no longer runs, so remove anything left:
   `docker ps -a --filter label=ckx.managed=true` (and the matching networks and
   volumes);
3. existing `ckx_session` cookies are ignored by the flag-off path; candidates
   start a new single-environment exam from the dashboard.

## Implementation notes

- Session model and ownership checks are implemented behind the flag
  (`POST /exams` issues a signed cookie; every `/exams/:examId/*` route verifies
  the session owns that exam).
- Per-session environments are implemented: the facilitator starts a Docker
  Compose stack (`k8s-api-server`, `jumphost`, `remote-desktop`,
  `remote-terminal`) on its own network with a per-session kubeconfig volume
  and VNC password. The cluster name is `ckx-<first 12 hex of the session id>`
  (k3d caps names at 32 characters, so the full UUID cannot be used), so each
  session's kubeconfig context differs. Startup reconciliation and the periodic
  reaper remove stacks without a session. The jumphost persists its session
  settings to `/etc/ckx-env` because SSH logins do not inherit the container
  environment.
- Expiry and limits (M6): idle and hard TTLs are enforced by a serialized
  reaper, per-session compose services declare CPU/memory limits, and
  `GET /api/v1/sessions` (admin token) exposes sessions plus metrics.
- Desktop and browser-terminal routing is per session (M4). The shared webapp
  forwards the browser's signed cookie to `GET /api/v1/sessions/me` (10 s
  cache) and proxies `/vnc-proxy`, `/websockify` and the `/ssh` socket to
  `ckx-<sid>-remote-desktop` / `ckx-<sid>-remote-terminal`. Without a session
  (flag off, anonymous, or after terminate) it falls back to the static
  single-environment targets.
- Those two containers join the shared `ckx-sessions` control network once;
  `k8s-api-server` and `jumphost` stay on the per-session network only. This
  avoids runtime network attach/detach, which resets established sockets.
- Each session gets random VNC and SSH passwords. The terminal password stays
  server-side in the webapp; `/api/session-info` only exposes the VNC password
  the browser needs.
- The dashboard is session-aware (M5): it resumes the caller's own
  CREATED/PREPARING/READY session on refresh, offers RESUME / TERMINATE for an
  active session, shows the 429 capacity message, and explains 403/404
  ownership errors on the exam, results, and answers pages.
- M8 verification (2026-11-11): three real labs (two identical `cks-002`
  sessions plus `ckad-003`) ran concurrently for 30 minutes, including a
  facilitator restart at minute 10. Checks covered distinct kubeconfig contexts
  and cluster-isolated namespaces, per-cookie desktop/terminal routing,
  cross-session 403/401 (foreign exam, tampered signature, no cookie, replay
  after terminate), independent grading of the identical labs (32% vs 31% with
  opposite verification flags), zero leftover `ckx.managed` resources, and
  freed-slot reuse.
