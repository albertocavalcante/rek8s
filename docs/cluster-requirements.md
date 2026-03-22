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

A Gateway API implementation (Contour, Envoy Gateway, Istio, Cilium) must
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
Network Policies: CiliumNetworkPolicy (cilium.io/v2)
Storage:          Local PV or cloud volumes
Monitoring:       Prometheus Operator + Hubble
```

**Required CRDs**:
- `cilium.io/v2`: CiliumNetworkPolicy
- `gateway.networking.k8s.io/v1`: GatewayClass, Gateway, HTTPRoute, GRPCRoute
- `cert-manager.io/v1`: Certificate, ClusterIssuer
- `monitoring.coreos.com/v1`: ServiceMonitor

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
CNI:              VPC CNI + Calico for NetworkPolicy
Ingress:          AWS ALB Controller or Contour
TLS:              cert-manager + ACM
Network Policies: Calico (projectcalico.org/v3)
Storage:          gp3 EBS
Monitoring:       Prometheus Operator
```

### `vanilla` (Minimal / CI / Dev)

```
CNI:              Any (flannel, kindnet, etc.)
Ingress:          nginx Ingress Controller
TLS:              Optional (self-signed)
Network Policies: Standard Kubernetes (if CNI supports)
Storage:          Default StorageClass
Monitoring:       Optional
```

**Required CRDs**:
- None beyond standard Kubernetes (Ingress v1 is built-in)
- Optionally cert-manager for TLS

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
