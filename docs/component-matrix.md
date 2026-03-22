# Component Comparison Matrix

## RBE Backends: Buildfarm vs Buildbarn

| Aspect | Buildfarm | Buildbarn |
|--------|-----------|-----------|
| **Language** | Java (Corretto 21) | Go |
| **License** | Apache-2.0 | Apache-2.0 |
| **Architecture** | Two-tier: server + worker | Multi-component: frontend, storage, scheduler, worker, runner |
| **Official Helm chart** | Yes (`oci://ghcr.io/buildfarm/buildfarm` v0.5.0) | No (Kustomize manifests only) |
| **Container registry** | Docker Hub (`bazelbuild/buildfarm-*`) | GHCR (`ghcr.io/buildbarn/*`) |
| **Backplane** | Redis (Bitnami subchart) | None (components communicate via gRPC) |
| **CAS storage** | Filesystem-based (XFS recommended), LRU eviction | Block-based, self-cleaning (no GC needed) |
| **Action Cache** | Redis-backed (4-week TTL) | Local block storage |
| **Worker isolation** | Single process (optional Docker) | Privilege separation: bb-worker (root) + bb-runner (unprivileged) |
| **Scaling model** | Server scales horizontally; workers via HPA | Frontend, storage, scheduler, workers all scale independently |
| **Client support** | Primarily Bazel | Bazel, Buck2, Reninja, Pants, BuildStream, recc |
| **Filesystem req.** | XFS strongly recommended (ext4 link limit) | Filesystem-agnostic |
| **Build browser** | No built-in UI | bb-browser (web UI for CAS/AC inspection) |
| **Autoscaler** | HPA (built into Helm chart) | bb-autoscaler (AWS ASG, EKS, K8s Deployment) |
| **Config format** | Protobuf text / YAML | Jsonnet -> JSON (protobuf schema) |
| **Complexity** | Lower (fewer moving parts) | Higher (more components, more control) |

### When to choose Buildfarm

- You want a simpler setup with fewer components to manage.
- Your team is comfortable with Java and the Bazel ecosystem.
- You prefer using the official, upstream-maintained Helm chart.
- You only need Bazel as a client (not Buck2, Reninja, Pants, etc.).

### When to choose Buildbarn

- You want fine-grained scaling control (scale frontend, storage, scheduler,
  and workers independently).
- You need privilege separation between the worker orchestrator and the
  build runner.
- You use multiple build systems (Buck2, Reninja, Pants, etc.) in addition to Bazel.
- You want self-cleaning CAS storage that doesn't require XFS.
- You want a CAS/AC browser UI for debugging failed actions.

---

## BES Backend: BuildBuddy OSS

| Feature | BuildBuddy OSS | BuildBuddy Enterprise |
|---------|----------------|----------------------|
| **Build Event Stream (BES)** | Yes | Yes |
| **Remote Cache** | Yes | Yes |
| **Web UI** | Yes | Yes (enhanced) |
| **Remote Build Execution** | No | Yes |
| **Authentication (OIDC/SAML)** | No | Yes |
| **API access** | No | Yes |
| **ClickHouse analytics** | No | Yes |
| **Redis caching layer** | No | Yes |
| **HPA for executors** | N/A | Yes |

BuildBuddy OSS is the only viable open-source BES backend with a web UI.
It also provides remote caching, which can be used standalone or alongside
a separate RBE backend (Buildfarm or Buildbarn).

**Note**: When using BuildBuddy OSS as BES alongside a separate RBE backend,
a **BES-capable** client sends build events to BuildBuddy (`--bes_backend`)
while sending execution requests to the RBE backend (`--remote_executor`).
These are independent gRPC connections.

**Important**: REAPI compatibility does not automatically imply BES support.
For a broader list of REAPI clients and servers, including NativeLink,
BuildGrid, Reclient, Siso, Pants, Please, and BuildStream, see
[`reapi-ecosystem.md`](reapi-ecosystem.md).

---

## Other RBE Servers Worth Tracking

These are not charted by rek8s today, but they are worth tracking in the wider
ecosystem:

| Provider | Type | Notes |
|---------|------|-------|
| **NativeLink** | Remote execution + cache | Broad compatibility story; current upstream license is `FSL-1.1-Apache-2.0` |
| **BuildGrid** | Remote execution + cache | Apache-2.0 REAPI server |
| **bazel-remote** | Remote cache only | Useful cache-only option; not a remote execution backend |

---

## REAPI Clients To Keep In Mind

Beyond Bazel, Buck2, and Reninja, the upstream `remote-apis` ecosystem also
lists:

- BuildStream
- Justbuild
- Pants
- Please
- Recc
- Reclient
- Siso

`Reclient` is especially important because it is not a build system by itself;
it integrates with an existing build system to enable remote execution and
caching.

---

## CRD Requirements by Cluster Profile

| CRD | calico-contour | calico-gateway-api | cilium-gateway-api | gke | vanilla |
|-----|:-:|:-:|:-:|:-:|:-:|
| `projectcalico.org/v3 NetworkPolicy` | Required | Required | -- | -- | -- |
| `projectcalico.org/v3 GlobalNetworkPolicy` | Optional | Optional | -- | -- | -- |
| `cilium.io/v2 CiliumNetworkPolicy` | -- | -- | Required | -- | -- |
| `networking.k8s.io/v1 NetworkPolicy` | -- | -- | -- | Required | Optional |
| `projectcontour.io/v1 HTTPProxy` | Required | -- | -- | -- | -- |
| `gateway.networking.k8s.io/v1 GatewayClass` | -- | Required | Required | Required | -- |
| `gateway.networking.k8s.io/v1 Gateway` | -- | Required | Required | Required | -- |
| `gateway.networking.k8s.io/v1 HTTPRoute` | -- | Required | Required | Required | -- |
| `gateway.networking.k8s.io/v1 GRPCRoute` | -- | Required | Required | Required | -- |
| `networking.k8s.io/v1 Ingress` | -- | -- | -- | -- | Required |
| `cert-manager.io/v1 Certificate` | Required | Required | Required | Required | Optional |
| `cert-manager.io/v1 ClusterIssuer` | Required | Required | Required | Required | Optional |
| `monitoring.coreos.com/v1 ServiceMonitor` | Recommended | Recommended | Recommended | Optional | -- |
| `policy/v1 PodDisruptionBudget` | Built-in | Built-in | Built-in | Built-in | -- |
| `autoscaling/v2 HPA` | Built-in | Built-in | Built-in | Built-in | -- |

---

## Port Summary

```
BES (BuildBuddy):
  8080/HTTP  -- Web UI, REST API
  1985/gRPC  -- BES, Remote Cache
  9090/HTTP  -- Prometheus metrics

RBE (Buildfarm):
  8980/gRPC  -- REAPI (Execution, CAS, AC, ByteStream)
  8982/gRPC  -- Worker peer-to-peer CAS
  9090/HTTP  -- Prometheus metrics
  6379/TCP   -- Redis backplane (internal)

RBE (Buildbarn):
  8980/gRPC  -- REAPI client endpoint (frontend)
  8981/gRPC  -- Storage shard internal
  8982/gRPC  -- Scheduler client port
  8983/gRPC  -- Scheduler worker port
  7982/HTTP  -- Scheduler dashboard
  7984/HTTP  -- Browser UI
  9980/HTTP  -- Prometheus metrics (all components)
```
