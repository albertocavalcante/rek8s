# rek8s Architecture

> Remote Execution on Kubernetes -- the Helm chart to rule them all.

## Overview

rek8s is an umbrella Helm chart that deploys a complete remote build
infrastructure on Kubernetes. It lets operators choose which **Build Event
Service (BES)** and which **Remote Build Execution (RBE)** backend to run,
while providing unified networking, security, observability, and storage
configuration that adapts to the target cluster's capabilities.

![rek8s overview](diagrams/overview.svg)

Source: [`diagrams/overview.d2`](diagrams/overview.d2)

## Component Matrix

| Role | Provider | Type | License | Notes |
|------|----------|------|---------|-------|
| **BES** | BuildBuddy OSS | Build Event Service + Remote Cache + UI | MIT | Only viable OSS BES with a web UI |
| **Cache** | bazel-remote | Remote Cache only | Apache-2.0 | HTTP + gRPC cache service, no remote execution |
| **RBE** | Buildfarm | Remote Execution + CAS | Apache-2.0 | Java, Redis backplane, official Helm chart |
| **RBE** | Buildbarn | Remote Execution + CAS | Apache-2.0 | Go, modular (bb-storage/scheduler/worker/runner), no official Helm chart |

For broader ecosystem context beyond the providers currently charted here, see
[`reapi-ecosystem.md`](reapi-ecosystem.md).

### Why these choices?

- **BuildBuddy OSS** is the only open-source project that provides a usable
  BES backend with a web UI. Its remote cache can also serve as the sole
  cache layer if RBE is not needed.
- **bazel-remote** is a cache-only service. It is useful when teams want a
  dedicated remote cache without introducing a BES UI or an execution backend.
- **Buildfarm** is the Bazel project's reference RBE implementation. It has
  an official Helm chart and a simpler two-tier architecture (server + worker).
- **Buildbarn** is the more modular, Go-based alternative. It separates
  concerns more aggressively (frontend, storage shards, scheduler, worker,
  runner) and uses a block-based self-cleaning CAS.
- **Reninja** is a Ninja-compatible REAPI client that can target the same
  BES, remote cache, and remote execution endpoints as Bazel and Buck2.
- **NativeLink** and **BuildGrid** are additional server implementations worth
  tracking, but they are not charted by rek8s today.

## Data Flow

![rek8s data flow](diagrams/data-flow.svg)

Source: [`diagrams/data-flow.d2`](diagrams/data-flow.d2)

## Namespace Layout

```
rek8s-system          # umbrella chart metadata, shared configmaps
rek8s-bes             # BES provider (BuildBuddy)
rek8s-cache           # cache provider (bazel-remote)
rek8s-rbe             # RBE provider (Buildfarm or Buildbarn)
rek8s-monitoring      # Prometheus ServiceMonitors, dashboards (optional)
```

All namespaces are created by the chart when `namespaces.create: true`.
Operators can override to deploy into existing namespaces.

## Port Allocation

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| BuildBuddy gRPC | 1985 | gRPC(S) | BES, Remote Cache APIs |
| BuildBuddy HTTP | 8080 | HTTP(S) | Web UI, REST |
| bazel-remote HTTP | 8080 | HTTP(S) | Cache status, metrics, REST cache API |
| bazel-remote gRPC | 9092 | gRPC(S) | Remote cache APIs |
| Buildfarm server | 8980 | gRPC(S) | REAPI (Execution, CAS, AC, ByteStream) |
| Buildfarm worker | 8982 | gRPC | Worker-to-worker CAS, health |
| Buildfarm metrics | 9090 | HTTP | Prometheus scrape |
| Buildbarn frontend | 8980 | gRPC(S) | REAPI client endpoint |
| Buildbarn storage | 8981 | gRPC | Internal storage shards |
| Buildbarn scheduler | 8982/8983 | gRPC | Client/worker scheduler |
| Buildbarn browser | 7984 | HTTP | CAS/AC browser UI |
| Buildbarn metrics | 9980 | HTTP | Prometheus scrape (all components) |

## Ingress Strategy

rek8s supports three ingress modes, selectable via `cluster.ingress.provider`:

1. **`contour`** -- Generates `HTTPProxy` resources (projectcontour.io/v1)
   with `protocol: h2c` for gRPC backends.
2. **`gateway-api`** -- Generates `GRPCRoute` and `HTTPRoute` resources
   (gateway.networking.k8s.io/v1) attached to a shared or per-service `Gateway`.
3. **`nginx`** -- Generates standard `Ingress` resources with
   `nginx.ingress.kubernetes.io` annotations for gRPC.

Each mode emits the correct TLS configuration using cert-manager
`Certificate` resources when `global.tls.enabled: true`.

## Network Security Model

When `cluster.networkPolicy.enabled: true`, rek8s generates
`NetworkPolicy` resources for every component. Two flavors are supported:

- **`calico`** -- Generates Calico `NetworkPolicy` (projectcalico.org/v3)
  with explicit `order` fields and `Log` actions for denied traffic.
- **`kubernetes`** -- Generates standard `NetworkPolicy`
  (networking.k8s.io/v1) compatible with any CNI that supports network
  policies.

### Default-Deny Posture

rek8s includes an optional `GlobalNetworkPolicy` (Calico) or namespace-scoped
default-deny policy that blocks all ingress/egress except:

- DNS (UDP/TCP 53 to kube-dns)
- Metrics scraping from the monitoring namespace
- Explicitly allowed inter-component traffic

### Inter-Component Traffic Matrix

| Source | Destination | Port | Purpose |
|--------|-------------|------|---------|
| Remote build client (external) | BES ingress | 1985 | Build events |
| Remote build client (external) | RBE ingress | 8980 | Remote execution / cache |
| Buildfarm server | Redis | 6379 | Backplane |
| Buildfarm worker | Redis | 6379 | Backplane |
| Buildfarm worker | Buildfarm worker | 8982 | Peer CAS transfer |
| Buildfarm worker | Buildfarm server | 8980 | Operation reporting |
| Buildbarn frontend | Buildbarn storage | 8981 | CAS/AC reads/writes |
| Buildbarn frontend | Buildbarn scheduler | 8982 | Execution dispatch |
| Buildbarn worker | Buildbarn scheduler | 8983 | Action polling |
| Buildbarn worker | Buildbarn storage | 8981 | Input fetch / output upload |
| Prometheus | All components | 9090/9980 | Metrics scraping |

## Storage Architecture

### RBE Storage

Both Buildfarm and Buildbarn use local persistent storage for CAS:

| Backend | Storage Type | Default Size | K8s Resource |
|---------|-------------|-------------|-------------|
| Buildfarm | Filesystem (XFS recommended) | 50Gi/worker | StatefulSet + PVC |
| Buildbarn | Block-based (self-cleaning) | 33Gi CAS + 1Gi AC/shard | StatefulSet + PVC |

### BES Storage

BuildBuddy supports pluggable blob storage:

| Backend | Config Key | Use Case |
|---------|-----------|----------|
| Disk (PVC) | `storage.disk` | Single-replica, dev/test |
| S3 / MinIO | `storage.s3` | Production, multi-replica |
| GCS | `storage.gcs` | Production on GCP |
| Azure Blob | `storage.azure` | Production on Azure |

### Database

BuildBuddy needs a SQL database for metadata:

| Backend | Config Key | Use Case |
|---------|-----------|----------|
| SQLite | `database.data_source: sqlite3://...` | Single-replica only |
| MySQL | `database.data_source: mysql://...` | Production, multi-replica |

## Observability

- **Prometheus metrics**: All components expose `/metrics`. rek8s generates
  `ServiceMonitor` resources when `observability.prometheus.enabled: true`.
- **Grafana dashboards**: Optional `ConfigMap`-based dashboard provisioning
  for Grafana when `observability.grafana.dashboards: true`.
- **BuildBuddy UI**: The BES UI itself provides build timing, logs, and
  artifact browsing at `https://bes.example.com`.
- **Buildbarn Browser**: Optional CAS/AC browser at `https://bb-browser.example.com`.
- **Client tooling**: See [`client-tooling.md`](client-tooling.md) for
  `bf-client`, `reclient`, and cache-only usage notes.

## High Availability

| Component | HA Strategy | Min Replicas |
|-----------|------------|--------------|
| BuildBuddy app | Horizontal scaling + MySQL | 2 |
| Buildfarm server | Horizontal scaling (stateless) | 2 |
| Buildfarm workers | HPA on CPU | 2 |
| Buildbarn frontend | Horizontal scaling (stateless) | 2 |
| Buildbarn storage | Sharded StatefulSet | 2 |
| Buildbarn scheduler | Single instance (leader election) | 1 |
| Redis (Buildfarm) | Sentinel or standalone | 1-3 |

All multi-replica workloads get `PodDisruptionBudget` resources with
`maxUnavailable: 1` by default.
