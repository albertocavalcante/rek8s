# rek8s

**Remote Execution on Kubernetes** -- an umbrella Helm chart for deploying
remote build infrastructure for Bazel, Buck2, Reninja, and other REAPI-capable
clients with pluggable BES and RBE providers.

---

rek8s lets you deploy a complete remote build stack on Kubernetes with a single
`helm install`. Pick your **Build Event Service** (BuildBuddy OSS) and your
**Remote Build Execution** backend (Buildfarm or Buildbarn), and rek8s handles
the networking, TLS, network policies, ingress, and observability adapted to
your cluster's specific capabilities.

![rek8s overview](docs/diagrams/overview.svg)

Source: [`docs/diagrams/overview.d2`](docs/diagrams/overview.d2)

## Why rek8s?

Setting up Bazel remote execution on Kubernetes involves deploying multiple
independent projects (BES server, RBE backend, Redis, storage), wiring them
together with gRPC-aware ingress, generating TLS certificates, writing network
policies so components can actually talk to each other in a default-deny
cluster, and configuring Prometheus scraping. Each of these projects has its
own deployment method, configuration format, and assumptions about the cluster.

rek8s solves this by providing:

- **One chart, one install** -- a single `values.yaml` controls everything.
- **Pluggable providers** -- swap BES or RBE backends without rewriting
  infrastructure config.
- **Cluster profiles** -- pre-tested values files for common cluster setups
  (Calico + Contour, Gateway API, GKE, vanilla dev clusters).
- **Network-policy-first** -- generates the exact inter-component allow rules
  for Calico or standard Kubernetes network policies, including default-deny.
- **gRPC-native ingress** -- correctly configured `HTTPProxy` (Contour),
  `GRPCRoute` (Gateway API), or annotated `Ingress` (nginx) for HTTP/2.
- **TLS everywhere** -- cert-manager `Certificate` resources for every
  exposed endpoint.

## Providers

| Role | Provider | What it does | License |
|------|----------|-------------|---------|
| **BES** | [BuildBuddy OSS](https://github.com/buildbuddy-io/buildbuddy-foss) | Build Event Service + Remote Cache + Web UI | MIT |
| **RBE** | [Buildfarm](https://github.com/bazelbuild/bazel-buildfarm) | Remote Execution + CAS (Java, Redis backplane) | Apache-2.0 |
| **RBE** | [Buildbarn](https://github.com/buildbarn) | Remote Execution + CAS (Go, modular architecture) | Apache-2.0 |

BES and RBE are **independent axes** -- you can deploy:
- BES only (build visibility + remote cache, no remote execution)
- RBE only (remote execution, no build event UI)
- BES + RBE (full stack)

Only one RBE provider can be active at a time (both implement the same
[Remote Execution API v2](https://github.com/bazelbuild/remote-apis)).

rek8s currently ships **Buildfarm** and **Buildbarn** as charted RBE providers.
Other notable REAPI servers worth tracking include
[NativeLink](https://github.com/TraceMachina/nativelink),
[BuildGrid](https://buildgrid.build/), and cache-only
[bazel-remote](https://github.com/buchgr/bazel-remote). See
[`docs/reapi-ecosystem.md`](docs/reapi-ecosystem.md).

## Quick Start

### Prerequisites

- Kubernetes v1.27+ (v1.29+ for Gateway API with `GRPCRoute`)
- Helm 3.x
- A cluster with a working ingress controller and CNI

### Install (dev / vanilla cluster)

```bash
helm install rek8s ./charts/rek8s \
  -f examples/cluster-profiles/vanilla.yaml
```

This deploys BuildBuddy OSS (BES + remote cache) and Buildfarm (RBE) with
minimal settings -- no TLS, no network policies, NodePort services.

### Install (production / Calico + Contour)

```bash
helm install rek8s ./charts/rek8s \
  -f examples/cluster-profiles/calico-contour.yaml \
  --set global.domain=build.mycompany.com
```

This deploys the full stack with:
- Calico network policies (default-deny + per-component allow rules)
- Contour HTTPProxy for gRPC ingress
- cert-manager TLS certificates
- Prometheus ServiceMonitors
- PodDisruptionBudgets and HPA

### Connect Bazel

Add to your project's `.bazelrc`:

```bash
# Remote cache + BES (no remote execution)
build:rek8s-cache --remote_cache=grpcs://bes-grpc.build.mycompany.com:443
build:rek8s-cache --bes_backend=grpcs://bes-grpc.build.mycompany.com:443
build:rek8s-cache --bes_results_url=https://bes.build.mycompany.com/invocation/

# Full remote execution
build:rek8s --remote_executor=grpcs://rbe.build.mycompany.com:443
build:rek8s --bes_backend=grpcs://bes-grpc.build.mycompany.com:443
build:rek8s --bes_results_url=https://bes.build.mycompany.com/invocation/
build:rek8s --jobs=50
build:rek8s --remote_timeout=3600
```

Then build:

```bash
bazel build --config=rek8s //...
```

See [`examples/bazelrc-buildfarm.bazelrc`](examples/bazelrc-buildfarm.bazelrc)
and [`examples/bazelrc-buildbarn.bazelrc`](examples/bazelrc-buildbarn.bazelrc)
for complete examples.

### Connect Reninja

Add to your project's `.ninjarc`:

```bash
build:rek8s-bes --bes_backend=grpcs://bes-grpc.build.mycompany.com:443
build:rek8s-bes --results_url=https://bes.build.mycompany.com/invocation

build:rek8s-cache --config=rek8s-bes
build:rek8s-cache --remote_cache=grpcs://rbe.build.mycompany.com:443

build:rek8s-remote --config=rek8s-cache
build:rek8s-remote --remote_executor=grpcs://rbe.build.mycompany.com:443
build:rek8s-remote -j 200
```

Then build:

```bash
reninja --config=rek8s-remote
```

See [`examples/reninja-buildfarm.ninjarc`](examples/reninja-buildfarm.ninjarc)
and [`examples/reninja-buildbarn.ninjarc`](examples/reninja-buildbarn.ninjarc)
for complete examples.

## Cluster Profiles

rek8s ships with pre-built values files for common Kubernetes environments.
Use them as-is or as a starting point for your own configuration.

| Profile | CNI | Ingress | Network Policy | TLS | Use Case |
|---------|-----|---------|---------------|-----|----------|
| [`calico-contour`](examples/cluster-profiles/calico-contour.yaml) | Calico | Contour HTTPProxy | Calico v3 | cert-manager | On-prem production |
| [`calico-gateway-api`](examples/cluster-profiles/calico-gateway-api.yaml) | Calico | Gateway API | Calico v3 | cert-manager | Modern on-prem |
| [`cilium-gateway-api`](examples/cluster-profiles/cilium-gateway-api.yaml) | Cilium | Gateway API / Cilium | Standard k8s | cert-manager | Generic Cilium clusters |
| [`vanilla-nginx`](examples/cluster-profiles/vanilla-nginx.yaml) | Any CNI with netpol support | ingress-nginx | Standard k8s | cert-manager | Generic upstream Kubernetes |
| [`docker-desktop`](examples/cluster-profiles/docker-desktop.yaml) | Docker Desktop | None (port-forward) | Disabled | Disabled | Local experimentation |
| [`gke`](examples/cluster-profiles/gke.yaml) | GKE Dataplane V2 | Gateway API | Standard k8s | cert-manager | Google Cloud |
| [`digitalocean`](examples/cluster-profiles/digitalocean.yaml) | DOKS / Cilium | Gateway API | Standard k8s | cert-manager | DigitalOcean Kubernetes |
| [`eks`](examples/cluster-profiles/eks.yaml) | AWS VPC CNI | ingress-nginx | Standard k8s | cert-manager | Amazon EKS |
| [`aks`](examples/cluster-profiles/aks.yaml) | Azure CNI / Cilium | Managed nginx | Standard k8s | cert-manager | Azure Kubernetes Service |
| [`oke`](examples/cluster-profiles/oke.yaml) | OKE CNI | ingress-nginx | Standard k8s | cert-manager | Oracle Kubernetes Engine |
| [`magalu-cloud`](examples/cluster-profiles/magalu-cloud.yaml) | Magalu Cloud | ingress-nginx | Standard k8s | cert-manager | Magalu Cloud Kubernetes |
| [`vultr-vke`](examples/cluster-profiles/vultr-vke.yaml) | Vultr / Calico | ingress-nginx | Standard k8s | cert-manager | Vultr Kubernetes Engine |
| [`linode-lke`](examples/cluster-profiles/linode-lke.yaml) | LKE / Calico | ingress-nginx | Standard k8s | cert-manager | Akamai Cloud / Linode Kubernetes Engine |
| [`scaleway-kapsule`](examples/cluster-profiles/scaleway-kapsule.yaml) | Kapsule / Cilium or Calico | ingress-nginx | Standard k8s | cert-manager | Scaleway Kubernetes Kapsule |
| [`ibm-cloud-vpc`](examples/cluster-profiles/ibm-cloud-vpc.yaml) | IBM Cloud VPC / Calico | ingress-nginx | Standard k8s | cert-manager | IBM Cloud Kubernetes Service |
| [`alibaba-ack`](examples/cluster-profiles/alibaba-ack.yaml) | ACK / Terway | ACK-managed nginx | Standard k8s | cert-manager | Alibaba Cloud ACK |
| [`k3s-traefik-gateway`](examples/cluster-profiles/k3s-traefik-gateway.yaml) | K3s / Flannel + kube-router | Gateway API / Traefik | Standard k8s | cert-manager | K3s edge or homelab |
| [`rke2-traefik-gateway`](examples/cluster-profiles/rke2-traefik-gateway.yaml) | RKE2 / Canal | Gateway API / Traefik | Standard k8s | cert-manager | RKE2 self-managed clusters |
| [`talos-cilium-gateway`](examples/cluster-profiles/talos-cilium-gateway.yaml) | Talos / Cilium | Gateway API / Cilium | Standard k8s | cert-manager | Talos self-managed clusters |
| [`vanilla`](examples/cluster-profiles/vanilla.yaml) | Any | None (NodePort) | Disabled | Disabled | Dev / CI |

```bash
# Use a profile
helm install rek8s ./charts/rek8s -f examples/cluster-profiles/gke.yaml

# Override specific values
helm install rek8s ./charts/rek8s \
  -f examples/cluster-profiles/calico-contour.yaml \
  --set global.domain=build.example.com \
  --set rbe.buildfarm.worker.replicaCount=8
```

For platform-specific deployment guidance and cloud gotchas, see
[`docs/major-platform-deployments.md`](docs/major-platform-deployments.md).
For self-managed distribution examples, see
[`docs/distribution-profiles.md`](docs/distribution-profiles.md).
For the next expansion wave and platform prioritization, see
[`docs/next-platform-roadmap.md`](docs/next-platform-roadmap.md).
For platforms that need a different support model, see
[`docs/platform-support-tracks.md`](docs/platform-support-tracks.md).

## Configuration

### Choosing an RBE Backend

<table>
<tr><td></td><td><strong>Buildfarm</strong></td><td><strong>Buildbarn</strong></td></tr>
<tr><td>Language</td><td>Java</td><td>Go</td></tr>
<tr><td>Architecture</td><td>Server + Workers (two-tier)</td><td>Frontend + Storage + Scheduler + Workers + Runners (modular)</td></tr>
<tr><td>CAS Storage</td><td>Filesystem (XFS recommended)</td><td>Block-based (self-cleaning, FS-agnostic)</td></tr>
<tr><td>Backplane</td><td>Redis</td><td>Direct gRPC</td></tr>
<tr><td>Worker Isolation</td><td>Single process</td><td>Privilege separation (worker/runner split)</td></tr>
<tr><td>Build System Support</td><td>Primarily Bazel</td><td>Bazel, Buck2, Reninja, Pants, BuildStream, recc</td></tr>
<tr><td>CAS Browser UI</td><td>No</td><td>Yes (bb-browser)</td></tr>
<tr><td>Complexity</td><td>Lower</td><td>Higher (more control)</td></tr>
</table>

```yaml
# Use Buildfarm
rbe:
  buildfarm:
    enabled: true
  buildbarn:
    enabled: false

# Or use Buildbarn
rbe:
  buildfarm:
    enabled: false
  buildbarn:
    enabled: true
```

### Key Values

```yaml
global:
  domain: "build.example.com"     # Base domain for all services
  storageClass: "gp3"             # Default StorageClass for PVCs
  tls:
    enabled: true                 # Generate cert-manager Certificates
    issuerRef:
      name: letsencrypt-prod
      kind: ClusterIssuer

bes:
  buildbuddy:
    enabled: true                 # Deploy BuildBuddy OSS
    replicaCount: 2
    storage:
      type: s3                    # disk | s3 | gcs | minio | azure
    database:
      type: mysql                 # sqlite | mysql

rbe:
  buildfarm:
    enabled: true
    server:
      replicaCount: 2
    worker:
      replicaCount: 4
      storage:
        size: 100Gi               # CAS storage per worker

cluster:
  networkPolicy:
    enabled: true
    provider: calico              # calico | kubernetes
  ingress:
    enabled: true
    provider: contour             # contour | gateway-api | nginx

observability:
  prometheus:
    serviceMonitor: true
```

See [`charts/rek8s/values.yaml`](charts/rek8s/values.yaml) for the complete
reference with all options documented.

## Architecture

### Data Flow

![rek8s data flow](docs/diagrams/data-flow.svg)

Source: [`docs/diagrams/data-flow.d2`](docs/diagrams/data-flow.d2)

### Namespace Layout

```
rek8s-bes             BES provider (BuildBuddy)
rek8s-rbe             RBE provider (Buildfarm or Buildbarn)
rek8s-monitoring      Prometheus ServiceMonitors (optional)
```

### Network Security

When network policies are enabled, rek8s generates the minimum required
allow rules for inter-component communication:

| Source | Destination | Port | Why |
|--------|-------------|------|-----|
| External (via ingress) | BES | 1985 | Build events + remote cache |
| External (via ingress) | RBE | 8980 | Remote execution |
| Buildfarm server | Redis | 6379 | Backplane coordination |
| Buildfarm workers | Redis | 6379 | Backplane coordination |
| Buildfarm workers | Buildfarm workers | 8982 | Peer-to-peer CAS transfer |
| Buildbarn frontend | Storage shards | 8981 | CAS/AC operations |
| Buildbarn frontend | Scheduler | 8982 | Execution dispatch |
| Buildbarn workers | Scheduler | 8983 | Action polling |
| Buildbarn workers | Storage shards | 8981 | Input fetch / output upload |
| Prometheus | All components | 9090/9980 | Metrics scraping |

With `cluster.networkPolicy.defaultDeny.enabled: true` (Calico), all other
traffic within the rek8s namespaces is denied.

## Repo Structure

```
rek8s/
├── charts/rek8s/                    # Umbrella Helm chart
│   ├── Chart.yaml                   # Dependencies: buildbuddy, buildfarm, buildbarn
│   ├── values.yaml                  # Full configuration reference
│   ├── templates/
│   │   ├── _helpers.tpl             # Template helpers + validation
│   │   ├── NOTES.txt                # Post-install instructions
│   │   ├── infrastructure/
│   │   │   ├── certificates/        # cert-manager Certificate resources
│   │   │   ├── ingress/             # Contour HTTPProxy + Gateway API routes
│   │   │   └── network-policies/    # Calico + standard k8s NetworkPolicy
│   │   └── shared/
│   │       └── _validation.yaml     # Input validation (e.g., single RBE provider)
│   └── charts/
│       ├── buildbuddy/              # BES subchart
│       ├── buildfarm/               # RBE subchart (wraps upstream)
│       └── buildbarn/               # RBE subchart (new, from bb-deployments)
├── docs/
│   ├── architecture.md              # System architecture and data flow
│   ├── design-decisions.md          # 12 ADRs with rationale
│   ├── cluster-requirements.md      # CRD prerequisites and resource sizing
│   ├── component-matrix.md          # Buildfarm vs Buildbarn comparison
│   └── diagrams/                    # D2 sources + generated SVG diagrams
├── scripts/
│   └── render-diagrams.sh           # D2 -> SVG renderer used by `just diagrams`
├── justfile                         # Convenience targets for docs diagrams
└── examples/
    ├── cluster-profiles/            # Pre-built values for common clusters
    │   ├── calico-contour.yaml
    │   ├── calico-gateway-api.yaml
    │   ├── gke.yaml
    │   └── vanilla.yaml
    ├── bazelrc-buildfarm.bazelrc    # .bazelrc for Buildfarm backend
    ├── bazelrc-buildbarn.bazelrc    # .bazelrc for Buildbarn backend
    ├── reninja-buildfarm.ninjarc    # .ninjarc for Buildfarm backend
    └── reninja-buildbarn.ninjarc    # .ninjarc for Buildbarn backend
```

## CRD Requirements

The base chart uses only core Kubernetes resources. Additional CRDs are needed
depending on which features you enable:

| Feature | CRDs Required |
|---------|--------------|
| TLS (`global.tls.enabled`) | `cert-manager.io/v1`: Certificate, ClusterIssuer |
| Contour ingress | `projectcontour.io/v1`: HTTPProxy |
| Gateway API ingress | `gateway.networking.k8s.io/v1`: GatewayClass, Gateway, HTTPRoute, GRPCRoute |
| Calico network policies | `projectcalico.org/v3`: NetworkPolicy, GlobalNetworkPolicy |
| Prometheus monitoring | `monitoring.coreos.com/v1`: ServiceMonitor |

See [docs/cluster-requirements.md](docs/cluster-requirements.md) for
installation instructions and the full CRD matrix per cluster profile.

## Resource Requirements

Minimum resource estimates for planning cluster capacity:

| Configuration | CPU | Memory | Storage |
|---------------|-----|--------|---------|
| BES only (2 replicas) | 1.5 cores | 1.5 Gi | 20 Gi |
| BES + Buildfarm (2 servers, 3 workers) | 4 cores | 7 Gi | 120 Gi |
| BES + Buildbarn (3 frontends, 2 shards, 8 workers) | 4 cores | 6 Gi | 70 Gi |

## Status

This project is in early development. The chart structure, subchart
scaffolding, infrastructure templates, and design documents are in place.

**What's done:**
- Umbrella chart with conditional subchart dependencies
- Infrastructure templates (Calico network policies, Contour + Gateway API
  ingress, cert-manager certificates)
- Subchart scaffolding for all three providers (BuildBuddy, Buildfarm,
  Buildbarn) with values and Chart.yaml
- Four cluster profiles with tested configurations
- Input validation (single RBE provider, gateway-api ref requirements)
- Design documentation (architecture, ADRs, cluster requirements, component
  matrix)

**What's next:**
- Subchart templates (Deployments, StatefulSets, Services, ConfigMaps)
- Standard Kubernetes NetworkPolicy templates (currently only Calico)
- nginx Ingress templates
- Grafana dashboard ConfigMaps
- CI pipeline (chart linting, kubeval, integration tests)
- Diagram pipeline (`just diagrams`) for D2 -> SVG docs assets
- Publish to a Helm repository

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/architecture.md) | System overview, data flow, port allocation, HA strategy |
| [Design Decisions](docs/design-decisions.md) | 12 architectural decision records with rationale |
| [Cluster Requirements](docs/cluster-requirements.md) | CRD prerequisites, cluster profiles, resource sizing |
| [Distribution Profiles](docs/distribution-profiles.md) | K3s and RKE2 deployment patterns via Traefik Gateway API |
| [Cluster API And Virtualization](docs/cluster-api-virtualization.md) | How to map Cluster API, vSphere, and Proxmox to real rek8s profiles |
| [Bare-Metal Load Balancers](docs/bare-metal-load-balancers.md) | MetalLB and host-network options for self-managed Gateway paths |
| [OpenShift Compatibility](docs/openshift-compatibility.md) | Current Route/SCC support status and next steps for ROSA/ARO |
| [Component Matrix](docs/component-matrix.md) | Buildfarm vs Buildbarn comparison, BES feature matrix |
| [Client Tooling](docs/client-tooling.md) | Operator/debug tooling such as bf-client, reclient, bb-clientd, and CAS utilities |
| [REAPI Ecosystem](docs/reapi-ecosystem.md) | Known REAPI servers and clients beyond the providers charted today |

## Related Projects

- [bazel-buildfarm](https://github.com/bazelbuild/bazel-buildfarm) --
  Bazel's reference RBE implementation
- [buildbarn](https://github.com/buildbarn) -- Modular Go-based RBE
- [buildbuddy-foss](https://github.com/buildbuddy-io/buildbuddy-foss) -- BES + Remote
  Cache (OSS) and RBE (Enterprise)
- [nativelink](https://github.com/TraceMachina/nativelink) -- Additional REAPI
  server worth tracking for future backend support
- [reninja](https://github.com/buildbuddy-io/reninja) -- Ninja-compatible
  REAPI client with BES, remote cache, and remote execution support
- [Remote Execution API](https://github.com/bazelbuild/remote-apis) --
  The protocol all RBE backends implement

## License

[MIT](LICENSE)
