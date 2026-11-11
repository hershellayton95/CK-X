# CKA-A Simulator - Solutions

This lab is adapted from the Killer.sh CKA Simulator A session (`Simulation-A.pdf`) and rewritten for the CK-X single-cluster k3d environment. Killer.sh content is credited to Killer.sh.

The original session solves tasks on several separate SSH instances and includes node-level exercises. CK-X provides one jumphost (`ckad9999`) plus SSH access to the cluster host (`k8s-api-server`), so these tasks are adapted as follows:

- Q8 (node update and join) is adapted to k3d: the cluster is managed by k3d/k3s, so the setup starts an older agent node and stops it. You delete that node and recreate it with the same k3s image as the control plane.
- Q14 (kube-apiserver certificate expiry and renewal) uses the real `kubeadm` binary on `ckad9999` against a kubeadm-style PKI directory at `/etc/kubernetes/pki`, built from the k3s control-plane certificates, because the cluster itself is k3d/k3s.
- Q17 uses `crictl` on the worker node via `ssh k8s-api-server "docker exec <node> crictl ..."`, matching the original task.
- Q13 uses a real NGINX Gateway Fabric controller, so the HTTPRoute is checked with actual HTTP traffic on NodePort `30080`.
- The PDF preview questions (etcd internals, node iptables, ServiceCIDR) are excluded because they require control-plane or node access.

All scratch files use `/tmp/exam`, which is removed during exam cleanup.

---

## Question 1: Kubeconfig contexts

```bash
K=/tmp/exam/1/kubeconfig

kubectl --kubeconfig "$K" config get-contexts -o name > /tmp/exam/1/contexts
kubectl --kubeconfig "$K" config current-context > /tmp/exam/1/current-context

kubectl --kubeconfig "$K" config view --raw \
  -o jsonpath='{.users[?(@.name=="account-0027@internal")].user.client-certificate-data}' \
  | base64 -d > /tmp/exam/1/cert
```

`config get-contexts -o name` prints one context per line. `config view --raw` is required to include certificate data. The `users` filter avoids relying on the array index.

Check the result:

```bash
cat /tmp/exam/1/contexts
cat /tmp/exam/1/current-context
head -1 /tmp/exam/1/cert
```

## Question 2: cert-manager with Helm

```bash
kubectl create namespace cert-manager

helm -n cert-manager install cert-manager jetstack/cert-manager \
  --set crds.enabled=true
```

The `jetstack` repository is already configured. `crds.enabled=true` installs the cert-manager CRDs, including `ClusterIssuer`.

Edit `/tmp/exam/2/cluster-issuer.yaml`:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: course-issuer
spec:
  selfSigned:
    crlDistributionPoints:
      - http://example.com/crl
```

Apply it:

```bash
kubectl apply -f /tmp/exam/2/cluster-issuer.yaml
kubectl get clusterissuer course-issuer
```

No certificate needs to be issued; installing the release and creating the ClusterIssuer is enough.

## Question 3: Scale down the StatefulSet

```bash
kubectl -n project-h800 get statefulset o3db
kubectl -n project-h800 scale statefulset o3db --replicas=1
kubectl -n project-h800 get statefulset o3db
kubectl -n project-h800 get pods -l app=o3db
```

Only `o3db-0` should remain. Scaling a StatefulSet down deletes the highest ordinal Pods first.

## Question 4: Pods terminated first

Pods with no CPU or memory requests/limits get QoS class `BestEffort`. Under node pressure they are evicted before `Burstable` and `Guaranteed` Pods.

```bash
kubectl -n project-c13 get pods \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.qosClass}{"\n"}{end}' \
  | awk '$2=="BestEffort"{print $1}' \
  | sort > /tmp/exam/4/pods-terminated-first.txt

cat /tmp/exam/4/pods-terminated-first.txt
```

The answer must contain exactly the current `BestEffort` Pod names.

## Question 5: Kustomize and HPA

The Kustomize tree is at `/tmp/exam/5/api-gateway` with `base`, `staging` and `prod`.

Remove the `horizontal-scaling-config` ConfigMap from:

- `base/api-gateway.yaml`
- `staging/api-gateway.yaml`
- `prod/api-gateway.yaml`

If it is removed only from the base, the overlay patches will fail because they no longer have a target.

Add the HPA to `base/api-gateway.yaml`:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-gateway
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-gateway
  minReplicas: 2
  maxReplicas: 4
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
```

Add the prod override to `prod/api-gateway.yaml`:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-gateway
spec:
  maxReplicas: 6
```

Apply both overlays and delete the existing ConfigMaps:

```bash
cd /tmp/exam/5/api-gateway
kubectl kustomize staging | kubectl apply -f -
kubectl kustomize prod | kubectl apply -f -

kubectl -n api-gateway-staging delete configmap horizontal-scaling-config --ignore-not-found
kubectl -n api-gateway-prod delete configmap horizontal-scaling-config --ignore-not-found
```

Kustomize does not track remote resources, so removing a resource from the YAML does not delete it from the cluster.

## Question 6: Static PV, PVC and Deployment

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: safari-pv
spec:
  capacity:
    storage: 2Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /Volumes/Data
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: safari-pvc
  namespace: project-t230
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
```

Create the PV and PVC, then confirm they are bound:

```bash
kubectl apply -f safari-storage.yaml
kubectl get pv safari-pv
kubectl -n project-t230 get pvc safari-pvc
```

The lab removes the default StorageClass annotation so the PVC does not get a default class and can bind to the classless PV.

Deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: safari
  namespace: project-t230
  labels:
    app: safari
spec:
  replicas: 1
  selector:
    matchLabels:
      app: safari
  template:
    metadata:
      labels:
        app: safari
    spec:
      containers:
        - name: container
          image: httpd:2-alpine
          volumeMounts:
            - name: data
              mountPath: /tmp/safari-data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: safari-pvc
```

## Question 7: Resource usage scripts

```bash
mkdir -p /tmp/exam/7
printf '%s\n' 'kubectl top node' > /tmp/exam/7/node.sh
printf '%s\n' 'kubectl top pod --containers=true' > /tmp/exam/7/pod.sh
chmod +x /tmp/exam/7/node.sh /tmp/exam/7/pod.sh
```

`kubectl top pod --containers=true` shows usage per container inside each Pod.

## Question 8: Update a worker node and join it

The cluster runs on k3d/k3s, so there is no kubeadm upgrade path. `k3d` cannot upgrade a node in place; the equivalent of "update the node and join it" is to delete the outdated node and create it again with the same k3s image as the control plane.

Find the control-plane version and image:

```bash
kubectl get node k3d-cluster-server-0
ssh k8s-api-server "docker inspect k3d-cluster-server-0 --format '{{.Config.Image}}'"
```

The image is `rancher/k3s:v1.31.5-k3s1`, matching `VERSION v1.31.5+k3s1`.

From the cluster host:

```bash
ssh k8s-api-server

k3d cluster list
k3d node list

k3d node delete k3d-cka-node1-0
```

`k3d node list` shows `k3d-cka-node1-0` as `exited`, and `kubectl get nodes` shows it as `NotReady`.

Back on `ckad9999`, remove the stale Node object and create the node again with the control-plane image:

```bash
kubectl delete node k3d-cka-node1-0 --ignore-not-found

ssh k8s-api-server \
  "k3d node create cka-node1 --cluster cluster --role agent \
   --image rancher/k3s:v1.31.5-k3s1 --wait"
```

The new node is `k3d-cka-node1-0` and joins the cluster automatically. Verify:

```bash
kubectl get nodes
kubectl get node k3d-cka-node1-0 -o wide
```

`k3d-cka-node1-0` must be `Ready` and show the same `VERSION` as `k3d-cluster-server-0` (`v1.31.5+k3s1`).

## Question 9: Contact the Kubernetes API from a Pod

Create the Pod:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: api-contact
  namespace: project-swan
spec:
  serviceAccountName: secret-reader
  containers:
    - name: api-contact
      image: nginx:1-alpine
```

Then query the API from inside it:

```bash
kubectl -n project-swan exec -it api-contact -- sh

TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
CACERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
curl --cacert "$CACERT" https://kubernetes.default/api/v1/secrets \
  -H "Authorization: Bearer ${TOKEN}" > /tmp/result.json
exit

kubectl -n project-swan exec api-contact -- cat /tmp/result.json \
  > /tmp/exam/9/result.json
```

If you use `curl -k`, that also works for this task. The important part is sending the ServiceAccount bearer token; without it the API sees `system:anonymous` and returns 403.

## Question 10: RBAC for a ServiceAccount

```bash
kubectl -n project-hamster create serviceaccount processor

kubectl -n project-hamster create role processor \
  --verb=create --resource=secrets --resource=configmaps

kubectl -n project-hamster create rolebinding processor \
  --role=processor \
  --serviceaccount=project-hamster:processor
```

Verify:

```bash
kubectl -n project-hamster auth can-i create secret \
  --as system:serviceaccount:project-hamster:processor
kubectl -n project-hamster auth can-i create configmap \
  --as system:serviceaccount:project-hamster:processor
kubectl -n project-hamster auth can-i get secret \
  --as system:serviceaccount:project-hamster:processor
```

The first two must be `yes`; the last must be `no`.

## Question 11: DaemonSet on every node

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: ds-important
  namespace: project-tiger
  labels:
    id: ds-important
    uuid: 18426a0b-5f59-4e10-923f-c0e078e82462
spec:
  selector:
    matchLabels:
      id: ds-important
      uuid: 18426a0b-5f59-4e10-923f-c0e078e82462
  template:
    metadata:
      labels:
        id: ds-important
        uuid: 18426a0b-5f59-4e10-923f-c0e078e82462
    spec:
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          effect: NoSchedule
      containers:
        - name: ds-important
          image: httpd:2-alpine
          resources:
            requests:
              cpu: 10m
              memory: 10Mi
```

The toleration lets the DaemonSet place a Pod on the tainted control-plane node. Check that the number of Pods equals the number of Ready nodes.

## Question 12: Deployment spread across workers

Use either pod anti-affinity or topology spread constraints. Pod anti-affinity example:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deploy-important
  namespace: project-tiger
  labels:
    id: very-important
spec:
  replicas: 3
  selector:
    matchLabels:
      id: very-important
  template:
    metadata:
      labels:
        id: very-important
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchExpressions:
                  - key: id
                    operator: In
                    values:
                      - very-important
              topologyKey: kubernetes.io/hostname
      containers:
        - name: container
          image: nginx:1-alpine
        - name: container2
          image: registry.k8s.io/pause:3.10
```

Topology spread equivalent:

```yaml
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              id: very-important
```

With a tainted control-plane node, each replica needs a distinct Ready worker. The number of Running Pods equals the number of Ready worker nodes; any remaining replica stays `Pending`.

## Question 13: Gateway API HTTPRoute

A real Gateway API controller (NGINX Gateway Fabric) runs in the cluster, so the routes are checked with actual HTTP requests. The old Ingress routes:

- `/desktop` -> `web-desktop:80`
- `/mobile` -> `web-mobile:80`

Create `/tmp/exam/13/httproute.yaml`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: traffic-director
  namespace: project-r500
spec:
  parentRefs:
    - name: main
  hostnames:
    - r500.gateway
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /desktop
      backendRefs:
        - name: web-desktop
          port: 80
    - matches:
        - path:
            type: PathPrefix
            value: /mobile
      backendRefs:
        - name: web-mobile
          port: 80
    - matches:
        - path:
            type: PathPrefix
            value: /auto
          headers:
            - name: user-agent
              type: Exact
              value: mobile
      backendRefs:
        - name: web-mobile
          port: 80
    - matches:
        - path:
            type: PathPrefix
            value: /auto
      backendRefs:
        - name: web-desktop
          port: 80
```

Apply it:

```bash
kubectl apply -f /tmp/exam/13/httproute.yaml
kubectl -n project-r500 get httproute traffic-director
```

Path and header in the same `matches` entry are ANDed. The catch-all `/auto` rule must come after the mobile rule, otherwise the mobile request never reaches the header rule.

Test the real traffic from `ckad9999`:

```bash
curl r500.gateway:30080/desktop
# web-desktop
curl r500.gateway:30080/mobile
# web-mobile
curl r500.gateway:30080/auto -H 'User-Agent: mobile'
# web-mobile
curl r500.gateway:30080/auto
# web-desktop
```

## Question 14: kube-apiserver certificate expiry

The cluster itself runs on k3d/k3s, so there is no kubeadm-managed control plane. The setup copies the k3s control-plane certificates into the default kubeadm PKI directory `/etc/kubernetes/pki`, and `kubeadm` is installed on `ckad9999`, so the real kubeadm commands from the original task work unchanged.

Check the certificate with openssl and write the date:

```bash
openssl x509 -noout -enddate -in /etc/kubernetes/pki/apiserver.crt \
  | sed 's/^notAfter=//' > /tmp/exam/14/expiration

cat /tmp/exam/14/expiration
```

Confirm with kubeadm. The `!MISSING!` lines are the other kubeadm certificates, which do not exist in a k3s PKI:

```bash
kubeadm certs check-expiration
```

The `apiserver` row must show the same date as `/tmp/exam/14/expiration`.

Renewal command:

```bash
printf '%s\n' 'kubeadm certs renew apiserver' \
  > /tmp/exam/14/kubeadm-renew-certs.sh

cat /tmp/exam/14/kubeadm-renew-certs.sh
```

`kubeadm certs renew apiserver` renews only the kube-apiserver serving certificate in `/etc/kubernetes/pki`.

## Question 15: Egress NetworkPolicy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: np-backend
  namespace: project-snake
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: db1
      ports:
        - protocol: TCP
          port: 1111
    - to:
        - podSelector:
            matchLabels:
              app: db2
      ports:
        - protocol: TCP
          port: 2222
```

Two separate rules mean `(db1 AND 1111) OR (db2 AND 2222)`. A single rule with both `to` entries and both ports would allow the wrong combinations, such as `db2:1111`.

Test from `backend-0`:

```bash
kubectl -n project-snake exec backend-0 -- wget -qO- http://<db1-pod-ip>:1111/
kubectl -n project-snake exec backend-0 -- wget -qO- http://<db2-pod-ip>:2222/
kubectl -n project-snake exec backend-0 -- wget -qO- http://<vault-pod-ip>:3333/   # must fail
```

## Question 16: CoreDNS custom domain

Back up the ConfigMap:

```bash
kubectl -n kube-system get configmap coredns -o yaml > /tmp/exam/16/coredns_backup.yaml
```

Edit it:

```bash
kubectl -n kube-system edit configmap coredns
```

Change the `kubernetes` plugin line from:

```text
kubernetes cluster.local in-addr.arpa ip6.arpa {
```

to:

```text
kubernetes custom-domain cluster.local in-addr.arpa ip6.arpa {
```

Restart CoreDNS:

```bash
kubectl -n kube-system rollout restart deployment coredns
kubectl -n kube-system rollout status deployment coredns
```

Test:

```bash
kubectl run dns-test --image=busybox:1.36 --restart=Never --rm -it -- \
  nslookup kubernetes.default.svc.custom-domain
```

Both `custom-domain` and `cluster.local` should resolve to the `kubernetes` Service IP.

## Question 17: Pod container information

Create the Pod:

```bash
kubectl -n project-tiger run tigers-reunite --image=httpd:2-alpine \
  --labels='pod=container,container=pod'
```

Find the node it runs on:

```bash
kubectl -n project-tiger get pod tigers-reunite -o wide
```

The cluster nodes are containers on `k8s-api-server`, so `crictl` runs on the node through `docker exec`. Replace `<node>` with the node name, for example `k3d-cluster-agent-0`:

```bash
ssh k8s-api-server "docker exec <node> crictl pods --name tigers-reunite -q"
# 0587e75b...   (pod sandbox ID)

ssh k8s-api-server "docker exec <node> crictl ps --pod <pod-id> -q"
# fc69a5a8...   (container ID)

ssh k8s-api-server "docker exec <node> crictl inspect <container-id>" \
  | jq -r '.status.id, .info.runtimeType'
# fc69a5a8...
# io.containerd.runc.v2
```

Write the container ID and runtime type, and the logs:

```bash
CID=$(ssh k8s-api-server "docker exec <node> crictl ps --pod <pod-id> -q")

printf '%s %s\n' "$CID" \
  "$(ssh k8s-api-server "docker exec <node> crictl inspect $CID" \
     | jq -r '.info.runtimeType')" \
  > /tmp/exam/17/pod-container.txt

ssh k8s-api-server "docker exec <node> crictl logs $CID" \
  > /tmp/exam/17/pod-container.log 2>&1
```

The runtime type is `io.containerd.runc.v2` (it contains `containerd`), and the logs contain the httpd startup messages. `crictl logs` writes the container stdout and stderr to separate streams; Apache writes its startup messages to stderr, so capture both with `2>&1`.
