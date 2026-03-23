# rek8s Cluster Requirements

This document defines the Kubernetes cluster prerequisites for deploying
rek8s, organized by cluster profile.

---

## Minimum Kubernetes Version

- **v1.27+** (for `autoscaling/v2` HPA, `policy/v1` PDB)
- **v1.29+** recommended (for Gateway API v1.1 GA with `GRPCRoute`)

---

## Required CRDs by Feature

### Always Required

None. The base chart produces only core Kubernetes resources (Deployments,
StatefulSets, Services, ConfigMaps, Secrets, PVCs, ServiceAccounts).

### When `global.tls.enabled: true`

| CRD | API Group | Installed By |
|-----|-----------|-------------|
| `Certificate` | `cert-manager.io/v1` | cert-manager |
| `ClusterIssuer` or `Issuer` | `cert-manager.io/v1` | cert-manager |

**Install cert-manager**:
```bash
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true
```

### When `cluster.ingress.provider: contour`

| CRD | API Group | Installed By |
|-----|-----------|-------------|
| `HTTPProxy` | `projectcontour.io/v1` | Contour |

**Install Contour**:
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install contour bitnami/contour --namespace projectcontour --create-namespace
```

### When `cluster.ingress.provider: gateway-api`

| CRD | API Group | Installed By |
|-----|-----------|-------------|
| `GatewayClass` | `gateway.networking.k8s.io/v1` | Gateway API CRDs |
| `Gateway` | `gateway.networking.k8s.io/v1` | Gateway API CRDs |
| `HTTPRoute` | `gateway.networking.k8s.io/v1` | Gateway API CRDs |
| `GRPCRoute` | `gateway.networking.k8s.io/v1` | Gateway API CRDs |
| `ReferenceGrant` | `gateway.networking.k8s.io/v1beta1` | Gateway API CRDs |

**Install Gateway API CRDs**:
```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml
```

A Gateway API implementation (Contour, Envoy Gateway, Istio, Cilium, Traefik) must
also be installed.

### When `cluster.networkPolicy.provider: calico`

| CRD | API Group | Installed By |
|-----|-----------|-------------|
| `NetworkPolicy` | `projectcalico.org/v3` | Calico (Tigera Operator) |
| `GlobalNetworkPolicy` | `projectcalico.org/v3` | Calico (Tigera Operator) |
| `NetworkSet` | `projectcalico.org/v3` | Calico (optional) |

**Install Calico**:
```bash
# Via Tigera Operator (recommended)
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/custom-resources.yaml
```

### When `cluster.networkPolicy.provider: kubernetes`

No additional CRDs required. The CNI must support standard
`networking.k8s.io/v1 NetworkPolicy`.

**rek8s behavior**:
- The standard Kubernetes policy path focuses on ingress isolation.
- Egress remains open by design so managed cloud storage, SQL, ACME, and other
  provider integrations continue to work without provider-specific exceptions.

### When `observability.prometheus.serviceMonitor: true`

| CRD | API Group | Installed By |
|-----|-----------|-------------|
| `ServiceMonitor` | `monitoring.coreos.com/v1` | Prometheus Operator / kube-prometheus-stack |

---

## Cluster Profiles

### `calico-contour` (On-Prem Standard)

```
CNI:              Calico
Ingress:          Contour (HTTPProxy)
TLS:              cert-manager
Network Policies: Calico (projectcalico.org/v3)
Storage:          Local PV or NFS (provide storageClass)
Monitoring:       Prometheus Operator
```

**Required CRDs**:
- `projectcalico.org/v3`: NetworkPolicy, GlobalNetworkPolicy
- `projectcontour.io/v1`: HTTPProxy
- `cert-manager.io/v1`: Certificate, ClusterIssuer
- `monitoring.coreos.com/v1`: ServiceMonitor

**Cluster setup checklist**:
- [ ] Calico installed as CNI plugin
- [ ] Contour deployed with Envoy
- [ ] cert-manager deployed with a ClusterIssuer configured
- [ ] Prometheus Operator deployed
- [ ] StorageClass available (XFS-formatted for Buildfarm workers)

### `calico-gateway-api` (Modern On-Prem)

```
CNI:              Calico
Ingress:          Gateway API (with Contour or Envoy Gateway)
TLS:              cert-manager
Network Policies: Calico (projectcalico.org/v3)
Storage:          Local PV or NFS
Monitoring:       Prometheus Operator
```

**Required CRDs**:
- `projectcalico.org/v3`: NetworkPolicy, GlobalNetworkPolicy
- `gateway.networking.k8s.io/v1`: GatewayClass, Gateway, HTTPRoute, GRPCRoute
- `cert-manager.io/v1`: Certificate, ClusterIssuer
- `monitoring.coreos.com/v1`: ServiceMonitor

### `cilium-gateway-api` (Cilium-Native)

```
CNI:              Cilium
Ingress:          Gateway API (Cilium-native)
TLS:              cert-manager
Network Policies: Standard Kubernetes NetworkPolicy
Storage:          Local PV or cloud volumes
Monitoring:       Prometheus Operator + Hubble
```

**Required CRDs**:
- `gateway.networking.k8s.io/v1`: GatewayClass, Gateway, HTTPRoute, GRPCRoute
- `cert-manager.io/v1`: Certificate, ClusterIssuer
- `monitoring.coreos.com/v1`: ServiceMonitor

Notes:
- `rek8s` currently uses standard Kubernetes `NetworkPolicy` for this path,
  not `CiliumNetworkPolicy`.
- Cilium-specific observability such as Hubble remains an operator choice
  outside the current chart.

### `gke` (Google Kubernetes Engine)

```
CNI:              GKE Dataplane V2 (Cilium-based)
Ingress:          Gateway API (GKE Gateway Controller)
TLS:              cert-manager or ManagedCertificate
Network Policies: Standard Kubernetes NetworkPolicy
Storage:          pd-ssd / pd-balanced
Monitoring:       Google Cloud Monitoring + Prometheus
```

**Required CRDs**:
- `gateway.networking.k8s.io/v1`: GatewayClass, Gateway, HTTPRoute, GRPCRoute
- `cert-manager.io/v1`: Certificate, ClusterIssuer
- `monitoring.coreos.com/v1`: ServiceMonitor (optional)

### `eks` (Elastic Kubernetes Service)

```
CNI:              AWS VPC CNI
Ingress:          ingress-nginx + AWS load balancer integration
TLS:              cert-manager
Network Policies: Standard Kubernetes NetworkPolicy
Storage:          gp3 EBS
Monitoring:       Prometheus Operator
```

Notes:
- Standard Kubernetes `NetworkPolicy` enforcement in EKS depends on Amazon VPC
  CNI network-policy support.
- The feature applies to Amazon EC2 Linux nodes, not Fargate or Windows nodes.

### `aks` (Azure Kubernetes Service)

```
CNI:              Azure CNI powered by Cilium
Ingress:          AKS application routing (managed nginx)
TLS:              cert-manager
Network Policies: Standard Kubernetes NetworkPolicy
Storage:          managed-csi / managed-csi-premium
Monitoring:       Azure Monitor or Prometheus Operator
```

### `digitalocean` (DigitalOcean Kubernetes)

```
CNI:              Cilium
Ingress:          Gateway API (Cilium)
TLS:              cert-manager
Network Policies: Standard Kubernetes NetworkPolicy
Storage:          do-block-storage
Monitoring:       DOKS monitoring or Prometheus Operator
```

### `oke` (Oracle Kubernetes Engine)

```
CNI:              OKE CNI
Ingress:          nginx Ingress Controller
TLS:              cert-manager
Network Policies: Standard Kubernetes NetworkPolicy via Calico policy engine
Storage:          oci-bv
Monitoring:       OCI Monitoring or Prometheus Operator
```

### `magalu-cloud` (Magalu Cloud Kubernetes)

```
CNI:              Calico on Magalu Cloud platform v3
Ingress:          nginx Ingress Controller
TLS:              cert-manager
Network Policies: Standard Kubernetes NetworkPolicy
Storage:          mgc-csi-magalu-sc
Monitoring:       Prometheus Operator (optional)
```

### `vultr-vke` (Vultr Kubernetes Engine)

```
CNI:              Calico
Ingress:          nginx Ingress Controller
TLS:              cert-manager
Network Policies: Standard Kubernetes NetworkPolicy
Storage:          vultr-block-storage
Monitoring:       Prometheus Operator (optional)
```

### `linode-lke` (Akamai Cloud / Linode Kubernetes Engine)

```
CNI:              Calico
Ingress:          nginx Ingress Controller
TLS:              cert-manager
Network Policies: Standard Kubernetes NetworkPolicy
Storage:          linode-block-storage
Monitoring:       Prometheus Operator (optional)
```

### `scaleway-kapsule` (Scaleway Kubernetes Kapsule)

```
CNI:              cilium or calico
Ingress:          nginx Ingress Controller
TLS:              cert-manager
Network Policies: Standard Kubernetes NetworkPolicy
Storage:          Default Scaleway Block Volume StorageClass
Monitoring:       Prometheus Operator (optional)
```

### `ibm-cloud-vpc` (IBM Cloud Kubernetes Service)

```
CNI:              Calico
Ingress:          nginx Ingress Controller
TLS:              cert-manager
Network Policies: Standard Kubernetes NetworkPolicy
Storage:          ibmc-vpc-block-10iops-tier
Monitoring:       IBM Cloud Monitoring or Prometheus Operator
```

### `alibaba-ack` (Alibaba Cloud ACK)

```
CNI:              Terway
Ingress:          ACK-managed NGINX Ingress Controller
TLS:              cert-manager
Network Policies: Standard Kubernetes NetworkPolicy
Storage:          alicloud-disk-topology-alltype
Monitoring:       Managed Prometheus or Prometheus Operator
```

Notes:
- NetworkPolicy support in ACK depends on creating the cluster with Terway and
  enabling the feature.
- Flannel clusters do not support NetworkPolicy.

### `k3s-traefik-gateway` (K3s with Traefik Gateway API)

```
CNI:              Flannel + kube-router network-policy controller
Ingress:          Gateway API (Traefik)
TLS:              cert-manager
Network Policies: Standard Kubernetes NetworkPolicy
Storage:          local-path
Monitoring:       Prometheus Operator (optional)
```

Notes:
- This profile is intended for K3s 1.32+ so packaged Traefik is v3.
- ServiceLB uses all nodes for the Traefik `LoadBalancer` Service by default,
  so ports 80 and 443 become unavailable for other HostPort or NodePort use.
- If you swap Flannel for another CNI, K3s documents that the built-in
  network-policy controller should also be disabled.

### `rke2-traefik-gateway` (RKE2 with Traefik Gateway API)

```
CNI:              Canal by default
Ingress:          Gateway API (Traefik)
TLS:              cert-manager
Network Policies: Standard Kubernetes NetworkPolicy
Storage:          Cluster default StorageClass
Monitoring:       Prometheus Operator (optional)
```

Notes:
- This profile assumes Canal, Calico, or Cilium. RKE2 documents that Flannel
  does not support network policies.
- RKE2 documents `ingress-nginx` end-of-life in March 2026 and says Traefik is
  the default for new v1.36 clusters.
- ServiceLB is optional on RKE2 and must be enabled explicitly when desired.

### `talos-cilium-gateway` (Talos with Cilium Gateway API)

```
CNI:              Cilium
Ingress:          Gateway API (Cilium)
TLS:              cert-manager
Network Policies: Standard Kubernetes NetworkPolicy
Storage:          Cluster default StorageClass
Monitoring:       Prometheus Operator (optional)
```

Notes:
- Talos Cilium installs start with `cluster.network.cni.name: none` in machine
  configuration and then install Cilium separately.
- Talos Cilium guidance assumes KubePrism is enabled on port 7445 for API
  access during CNI bootstrap.
- Talos Ingress Firewall is host-level and separate from pod/service traffic;
  Talos documents that Cilium Host Firewall may take precedence over OS-level
  rules.

### `docker-desktop` (Local Docker Desktop)

```
CNI:              Docker Desktop default
Ingress:          None (port-forward)
TLS:              Disabled
Network Policies: Disabled
Storage:          Docker Desktop default StorageClass
Monitoring:       Optional
```

### `vanilla-nginx` (Generic Upstream Kubernetes)

```
CNI:              Any CNI with NetworkPolicy support
Ingress:          ingress-nginx
TLS:              cert-manager
Network Policies: Standard Kubernetes NetworkPolicy
Storage:          Default or operator-provided StorageClass
Monitoring:       Optional
```

### `vanilla` (Minimal / CI / Dev)

```
CNI:              Any (flannel, kindnet, etc.)
Ingress:          None (NodePort / port-forward)
TLS:              Disabled by default
Network Policies: Disabled by default
Storage:          Default StorageClass
Monitoring:       Optional
```

**Required CRDs**:
- None beyond standard Kubernetes
- Optionally cert-manager and an ingress controller if you evolve toward
  `vanilla-nginx`

---

## Resource Requirements (Minimum)

### BES (BuildBuddy OSS)

| Component | CPU Request | Memory Request | Storage |
|-----------|------------|----------------|---------|
| App (per replica) | 500m | 512Mi | 10Gi PVC (disk storage) |
| MySQL (if internal) | 250m | 512Mi | 10Gi PVC |

### RBE (Buildfarm)

| Component | CPU Request | Memory Request | Storage |
|-----------|------------|----------------|---------|
| Server (per replica) | 500m | 1Gi | -- |
| Worker (per replica) | 1000m | 2Gi | 50Gi PVC |
| Redis | 250m | 256Mi | 1Gi PVC |

### RBE (Buildbarn)

| Component | CPU Request | Memory Request | Storage |
|-----------|------------|----------------|---------|
| Frontend (per replica) | 250m | 256Mi | -- |
| Storage shard (per replica) | 500m | 1Gi | 33Gi CAS + 1Gi AC PVC |
| Scheduler | 250m | 256Mi | -- |
| Worker (per replica) | 1000m | 2Gi | -- |
| Browser (per replica) | 100m | 128Mi | -- |

### Total Minimum (BES + RBE)

| Configuration | Nodes | Total CPU | Total Memory | Total Storage |
|---------------|-------|-----------|-------------|---------------|
| BES only (2 replicas) | 2 | 1.5 cores | 1.5Gi | 20Gi |
| BES + Buildfarm (min) | 3 | 4 cores | 7Gi | 120Gi |
| BES + Buildbarn (min) | 3 | 4 cores | 6Gi | 70Gi |

---

## Filesystem Considerations

### Buildfarm Workers

Buildfarm's CAS uses hardlinks extensively. **XFS is strongly recommended**
for worker PVCs because ext4 has a 65,000 link-per-inode limit that can be
exhausted under heavy load.

If your StorageClass provisions ext4 volumes, either:
1. Use a StorageClass that formats as XFS (`fsType: xfs`)
2. Or configure Buildfarm to use `execRootCopyFallback: true` (slower)

### Buildbarn Storage Shards

Buildbarn uses a block-based storage format that is filesystem-agnostic.
No special filesystem requirements.
