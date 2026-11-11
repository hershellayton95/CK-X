# CKA Mock Exam 1 - Answers & Explanations

> Questions adapted from **Mock Exam 1** of the free [KodeKloud CKA course notes](https://github.com/kodekloudhub/certified-kubernetes-administrator-course) (credited to KodeKloud), adapted to this simulator's k3d environment: output files live under `/tmp/exam/` and node names follow the `k3d-cluster-*` convention.

## Question 1: Create pod nginx-pod

### Solution

```bash
kubectl run nginx-pod --image=nginx:alpine --labels=run=nginx-pod
```

Or with a manifest:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  namespace: default
  labels:
    run: nginx-pod
spec:
  containers:
  - name: nginx-pod
    image: nginx:alpine
```

### Explanation

`kubectl run` creates a pod imperatively; `--labels` sets the required label in one shot. The verification checks image **and** label, so a plain `kubectl run nginx-pod --image=nginx:alpine` (no label) would fail.

## Question 2: Create pod messaging

### Solution

```bash
kubectl run messaging --image=redis:alpine --labels=tier=msg
```

### Explanation

Same pattern as question 1 - the label `tier=msg` is what the later `messaging-service` (question 5) will select on.

## Question 3: Create namespace apx-x9984574

### Solution

```bash
kubectl create namespace apx-x9984574
```

### Explanation

Namespaces are created with `kubectl create namespace` (or `kubectl create ns`). The phase must be `Active` - a namespace stuck in `Terminating` would fail verification.

## Question 4: Export nodes as JSON

### Solution

```bash
mkdir -p /tmp/exam/outputs
kubectl get nodes -o json > /tmp/exam/outputs/nodes-z3444kd9.json
```

### Explanation

`-o json` emits a full `NodeList` document with an `items` array - exactly what the verification parses. Plain `kubectl get nodes` (table output) is not valid JSON and fails.

## Question 5: Expose pod messaging

### Solution

```bash
kubectl expose pod messaging --port=6379 --name=messaging-service
```

### Explanation

`kubectl expose pod` builds a `ClusterIP` service from the pod's labels - here `tier=msg` - so the selector matches automatically. You can check with `kubectl get endpoints messaging-service`; an empty endpoints list means the selector doesn't match the pod.

## Question 6: Deployment hr-web-app

### Solution

```bash
kubectl create deployment hr-web-app \
  --image=kodekloud/webapp-color \
  --replicas=2
```

Or with a manifest:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hr-web-app
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hr-web-app
  template:
    metadata:
      labels:
        app: hr-web-app
    spec:
      containers:
      - name: webapp-color
        image: kodekloud/webapp-color
```

### Explanation

The deployment name `hr-web-app` does **not** automatically give the pods an `app=hr-web-app` label when using `kubectl create deployment` (it sets `app=hr-web-app` only because the label is derived from the name - if you rename the deployment, set the label explicitly). The verification checks replicas, image, selector/template labels, and that both replicas become available.

## Question 7: Static pod static-busybox

### Solution

Create `/etc/kubernetes/manifests/static-busybox.yaml` on `cka9999`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: static-busybox
  labels:
    run: static-busybox
spec:
  containers:
  - name: static-busybox
    image: busybox
    command: ["sleep", "1000"]
```

```bash
mkdir -p /etc/kubernetes/manifests
cat > /etc/kubernetes/manifests/static-busybox.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: static-busybox
  labels:
    run: static-busybox
spec:
  containers:
  - name: static-busybox
    image: busybox
    command: ["sleep", "1000"]
EOF
```

### Explanation

Static pods are declared as manifest files in the kubelet's static pod path (`/etc/kubernetes/manifests` on `cka9999`). The kubelet watches that directory and creates the pod - no API object is submitted by you. The verification checks the file's content: kind, name, image, command, and label.

## Question 8: Pod temp-bus in namespace finance

### Solution

```bash
kubectl run temp-bus --image=redis:alpine -n finance
```

### Explanation

The `finance` namespace is pre-created for you - the task is only the pod. Forgetting `-n finance` puts the pod in `default` and fails verification.

## Question 9: Troubleshoot pod orange

### Solution

```bash
kubectl describe pod orange -n default
```

The events show: `exec: "sleeeep": executable file not found in $PATH`.

```bash
kubectl get pod orange -o yaml > /tmp/exam/orange.yaml
# fix: sleeeep -> sleep
sed -i 's/sleeeep/sleep/' /tmp/exam/orange.yaml
kubectl delete pod orange
kubectl create -f /tmp/exam/orange.yaml
```

### Explanation

Pods with a bad `command` are stuck in `ContainerCreating` / `CreateContainerError` - the pod object is fine, the container spec is not. You cannot edit a pod's spec in place, so export → fix → delete → recreate is the standard pattern. The verification requires the pod back in `Running` with `sleep` (not `sleeeep`) as the command.

## Question 10: Service hr-web-app-service

### Solution

```yaml
apiVersion: v1
kind: Service
metadata:
  name: hr-web-app-service
  namespace: default
spec:
  type: NodePort
  selector:
    app: hr-web-app
  ports:
  - port: 8080
    targetPort: 8080
    nodePort: 30082
```

```bash
kubectl apply -f hr-web-app-service.yaml
```

### Explanation

NodePort services need `type: NodePort` and a `nodePort` in the 30000-32767 range (30082 here). The selector `app=hr-web-app` must match the deployment's pod labels from question 6, otherwise the service has no endpoints.

## Question 11: Export node osImage values

### Solution

```bash
mkdir -p /tmp/exam/outputs
kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.osImage}' \
  > /tmp/exam/outputs/nodes_os_x43kj56.txt
```

### Explanation

JSONPath with `{.items[*].status.nodeInfo.osImage}` expands to one space-separated line with one entry per node. The verification checks the entry count equals the node count, so omitting nodes or adding extra text fails.

## Question 12: PersistentVolume pv-analytics

### Solution

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-analytics
spec:
  capacity:
    storage: 100Mi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteMany
  hostPath:
    path: /pv/data-analytics
```

```bash
kubectl apply -f pv-analytics.yaml
```

### Explanation

A `hostPath` PV is statically provisioned - no storage class needed. `ReadWriteMany` and the exact capacity/path are checked; `accessModes` is a list, so `[ReadWriteMany]` must be the first entry.
