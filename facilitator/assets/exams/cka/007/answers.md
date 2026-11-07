# CKA Mixed-Source Lab - Answers & Explanations

> Mixed-source lab. Questions adapted from three free, public repos (credited to their authors):
> - Questions 1-2 adapted from **Variation A** and **Variation B** of the MIT-licensed [kubeskills/cka-under-pressure](https://github.com/kubeskills/cka-under-pressure) KubeCon NA 2026 tip-talk companion (credited to kubeskills), keeping their distinctive constraints (the Deployment and its running Pods must not be touched; the readiness check must remain defined and `publishNotReadyAddresses` must not be set).
> - Questions 3, 4, 6, 7, 8, 9, 10 adapted from the [KodeKloud CKA course notes](https://github.com/kodekloudhub/certified-kubernetes-administrator-course) (credited to KodeKloud): DaemonSets and Init Containers practice tests, the Image Security practice test, Lightning Lab 1 (Q2, Q5, Q7) and an Ultimate Mocks troubleshooting task.
> - Question 5 adapted from **Mock Exam 01** of the MIT-licensed [theplatformlab/CKA-Certified-Kubernetes-Administrator](https://github.com/theplatformlab/CKA-Certified-Kubernetes-Administrator) (credited to theplatformlab).
>
> Adapted to this simulator's kubectl-only k3d environment: output files live under `/tmp/exam/`, node names follow the `k3d-cluster-*` convention, Question 2's app is nginx (which answers on `/`) instead of the talk's custom app that serves `/healthz`, and Question 9's NetworkPolicy deny-direction is validated at spec level because the lab cluster's CNI does not enforce NetworkPolicy (the allow-direction is checked live).

## Question 1: Service selector mismatch (fix the Service, not the Deployment)

### Diagnosis

```bash
kubectl -n drill-variation-a get service web -o wide
kubectl -n drill-variation-a get endpointslices -l kubernetes.io/service-name=web
kubectl -n drill-variation-a get pods --show-labels
```

The Service looks for `app=web`, but the Pods carry `app.kubernetes.io/name=web` - no Pod ever matches, so the Service has no endpoints. The running Pods are healthy, so the smallest change that leaves the Deployment (and its running Pods) untouched is to point the Service at the label the Pods already have.

### Solution

```bash
kubectl -n drill-variation-a set selector service web app.kubernetes.io/name=web
# (or: kubectl -n drill-variation-a edit service web  ->  fix .spec.selector)

# verify behavior, not just the command
kubectl -n drill-variation-a get endpointslices -l kubernetes.io/service-name=web

# verify like a client, from inside the namespace
kubectl -n drill-variation-a exec deploy/report -- wget -qO- -T 5 http://web:80/
```

Do **not** touch the Deployment: the validation checks `.metadata.generation` is still `1` and that the three original Pods (recorded at setup) are still running with their original identities.

## Question 2: Readiness probe checks a path the app does not serve

### Diagnosis

```bash
kubectl -n drill-variation-b get pods                 # Running, but 0/3 Ready
kubectl -n drill-variation-b describe pod -l app.kubernetes.io/name=web
kubectl -n drill-variation-b logs -l app.kubernetes.io/name=web --tail=5
kubectl -n drill-variation-b get deploy web -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}{"\n"}'
```

The Pods run but never become Ready: the readiness probe GETs `/ready`, and nginx answers `404` for that path (the access log in `kubectl logs` shows the failing requests) while `/` returns `200`. Because the Pods are never Ready, the Service has no ready endpoints.

### Solution

```bash
# smallest change: make the check ask for a path the app answers on. KEEP the check.
kubectl -n drill-variation-b patch deployment web --type json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/"}]'
kubectl -n drill-variation-b rollout status deploy/web --timeout=120s

# verify: all ready endpoints, then like a client
kubectl -n drill-variation-b get endpointslices -l kubernetes.io/service-name=web
kubectl -n drill-variation-b exec deploy/report -- wget -qO- -T 5 http://web:80/
```

Constraints enforced by the validations: the `readinessProbe` must still exist (only its path may change), and `publishNotReadyAddresses` must **not** be set on the Service - unhealthy Pods must never receive traffic.

## Question 3: Create a DaemonSet

### Solution

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: log-shipper
  namespace: logging
spec:
  selector:
    matchLabels:
      app: log-shipper
  template:
    metadata:
      labels:
        app: log-shipper
    spec:
      containers:
        - name: agent
          image: busybox:1.36
          command: ["sh", "-c", "while true; do sleep 3600; done"]
EOF

kubectl -n logging rollout status ds/log-shipper --timeout=120s
kubectl -n logging get pods -o wide    # one pod per node, including k3d-cluster-server-0
```

The selector must match the template labels (`app=log-shipper`), and the DaemonSet controller places exactly one pod on every node - the cluster's control-plane node has no taint, so a pod runs there too.

## Question 4: imagePullSecrets for a private registry

### Solution

```bash
kubectl -n image-security create secret docker-registry private-reg-cred \
  --docker-server=myprivateregistry.com:5000 \
  --docker-username=dock_user \
  --docker-password=dock_password \
  --docker-email=dock_user@myprivateregistry.com

kubectl -n image-security patch deployment web --type json \
  -p='[{"op":"add","path":"/spec/template/spec/imagePullSecrets","value":[{"name":"private-reg-cred"}]}]'
# or edit the Deployment and add under spec.template.spec:
#   imagePullSecrets:
#     - name: private-reg-cred

kubectl -n image-security rollout status deploy/web --timeout=120s
```

Do not change the image - it must stay `nginx:1.27` (a pull from `myprivateregistry.com` would never succeed anyway; only the Secret and the `imagePullSecrets` reference are graded).

## Question 5: PodDisruptionBudget + node maintenance drain

### Solution

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: critical-db-pdb
  namespace: maintenance
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: critical-db
EOF

# prepare the node
kubectl cordon k3d-cluster-agent-1
kubectl drain k3d-cluster-agent-1 --ignore-daemonsets
# (add --delete-emptydir-data if a pod with emptyDir data blocks the drain)

# the marker job's pod is gone and is never recreated (backoffLimit: 0)
kubectl -n maintenance get pods -l job-name=maintenance-marker

# hand the node back
kubectl uncordon k3d-cluster-agent-1

kubectl -n maintenance rollout status deploy/critical-db --timeout=120s
```

With `minAvailable: 2` and 3 replicas, each eviction leaves at least 2 Pods running, so the drain proceeds one Pod at a time while respecting the budget. The `--ignore-daemonsets` flag is required because DaemonSet pods (traefik, svclb) live on the node and are never drained.

## Question 6: Mount a Secret as a read-only volume

### Solution

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: secret-1401
  namespace: admin1401
  labels:
    run: secret-1401
spec:
  nodeSelector:
    kubernetes.io/hostname: k3d-cluster-agent-0
  volumes:
    - name: secret-volume
      secret:
        secretName: dotfile-secret
  containers:
    - name: secret-admin
      image: busybox:1.36
      command: ["sleep", "4800"]
      volumeMounts:
        - name: secret-volume
          readOnly: true
          mountPath: /etc/secret-volume
EOF

kubectl -n admin1401 get pod secret-1401
kubectl -n admin1401 exec secret-1401 -- ls /etc/secret-volume
```

The `readOnly: true` on the **volume mount** is part of the spec - the validation checks it, along with the `nodeSelector` that keeps this pod safe from Question 5's drain.

## Question 7: Export deployments with custom-columns

### Solution

```bash
kubectl -n admin2406 get deployment \
  -o custom-columns=DEPLOYMENT:.metadata.name,CONTAINER_IMAGE:.spec.template.spec.containers[].image,READY_REPLICAS:.status.readyReplicas,NAMESPACE:.metadata.namespace \
  --sort-by=.metadata.name > /tmp/exam/outputs/admin2406_data

cat /tmp/exam/outputs/admin2406_data
```

`custom-columns` prints the header row automatically; `--sort-by=.metadata.name` gives the required ascending order. The file must be written to `/tmp/exam/outputs/admin2406_data` (create the directory first if needed: `mkdir -p /tmp/exam/outputs` - the setup already does).

## Question 8: Diagnose and fix the missing PVC (alpha-mysql)

### Diagnosis

```bash
kubectl -n alpha get pods
kubectl -n alpha describe pod -l app=alpha-mysql | tail -5
#   Warning  FailedMount ... persistentvolumeclaim "mysql-alpha-pvc" not found
kubectl get pv alpha-pv     # capacity 1Gi, RWO, storageClassName slow, hostPath /opt/alpha
```

The Deployment mounts a PVC that was never created. The PV already exists, so the claim must be crafted to match it - the validation also checks that `alpha-pv` itself is unaltered.

### Solution

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-alpha-pvc
  namespace: alpha
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: slow
EOF

kubectl -n alpha get pvc mysql-alpha-pvc     # Bound to alpha-pv
kubectl -n alpha rollout status deploy/alpha-mysql --timeout=120s
```

Capacity (`1Gi`), access mode (`ReadWriteOnce`) and storage class (`slow`) all come from inspecting `alpha-pv`.

## Question 9: NetworkPolicy with an AND-rule (wrong port, over-broad source)

### Diagnosis

```bash
kubectl -n cyan-ns get netpol cyan-np -o yaml
kubectl -n cyan-ns exec cyan-white -- wget -qO- -T 5 http://cyan-svc:80/   # times out
```

Two faults:

1. The ingress rule opens port `8080`, but the nginx app listens on `80` - so nothing connects.
2. The `from` clause is a bare `namespaceSelector` (the whole namespace) - once you fix the port, *every* Pod in `cyan-ns` could connect, including `cyan-black`.

### Solution

```bash
kubectl -n cyan-ns edit netpol cyan-np
```

The finished rule - note that `podSelector` sits **inside the same `from` entry** as `namespaceSelector` (no dash before it), which AND-combines them. Separate array entries would be OR-combined and let the whole namespace in:

```yaml
spec:
  podSelector:
    matchLabels:
      app: cyan-app
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: cyan-ns
          podSelector:                 # same entry -> AND, not OR
            matchLabels:
              client: white
      ports:
        - port: 80
```

Verify the allow-direction live:

```bash
kubectl -n cyan-ns exec cyan-white -- wget -qO- -T 8 http://cyan-svc:80/
```

(The deny-direction for `cyan-black` is validated at spec level - the lab cluster's CNI does not enforce NetworkPolicy.)

## Question 10: Create a Pod with an init container

### Solution

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: init-demo
  namespace: init-ex
  labels:
    app: init-demo
spec:
  nodeSelector:
    kubernetes.io/hostname: k3d-cluster-agent-0
  initContainers:
    - name: init-setup
      image: busybox:1.36
      command: ["sh", "-c", "echo preparing; sleep 10"]
  containers:
    - name: app
      image: nginx:1.27
      ports:
        - containerPort: 80
EOF

kubectl -n init-ex get pod init-demo
kubectl -n init-ex get pod init-demo -o jsonpath='{.status.initContainerStatuses[0].state.terminated.reason}{"\n"}'
# Completed
```

The kubelet runs `init-setup` to completion first (`Completed`, exit code 0) and only then starts `app`. The `nodeSelector` keeps the pod on `k3d-cluster-agent-0`, safe from Question 5's drain.
