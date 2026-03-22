# rek8s Design Decisions

This document records the key architectural decisions and their rationale.

---

## DD-001: Umbrella Chart with Conditional Subcharts

**Decision**: Use a single umbrella Helm chart (`rek8s`) that includes BES
and RBE providers as conditional subchart dependencies.

**Rationale**:
- Operators install one chart and configure which providers to enable.
- Shared infrastructure (network policies, ingress, TLS, observability) is
  managed in the parent chart and consistently applied regardless of provider.
- Subchart conditions (`bes.buildbuddy.enabled`, `rbe.buildfarm.enabled`,
  `rbe.buildbarn.enabled`) prevent unused components from being templated.

**Alternatives Considered**:
- Separate charts per provider: More flexible but forces operators to manage
  cross-chart dependencies (shared TLS, network policies, DNS) manually.
- Kustomize overlays: Good for Buildbarn (which already uses Kustomize) but
  doesn't compose well with Buildfarm's Helm chart.

---

## DD-002: BES and RBE as Independent Axes

**Decision**: BES and RBE are independently selectable. You can run:
- BES only (BuildBuddy OSS for build visibility + remote cache)
- RBE only (Buildfarm or Buildbarn for remote execution, no BES UI)
- BES + RBE (full stack)

**Rationale**:
- Many teams start with remote caching and BES before adopting RBE.
- BuildBuddy OSS provides remote cache that may be sufficient without RBE.
- Decoupling allows gradual adoption.

---

## DD-003: BuildBuddy OSS as the BES Provider

**Decision**: Use BuildBuddy OSS as the sole BES provider.

**Rationale**:
- It is the only open-source BES implementation with a web UI.
- It also provides remote cache, which can serve teams not yet using RBE.
- Buildbarn's `bb-portal` is experimental and less mature.
- The official Helm chart is well-maintained.

**Future**: If bb-portal matures, add it as a second BES option.

---

## DD-004: Buildfarm vs. Buildbarn -- Offer Both

**Decision**: Support both Buildfarm and Buildbarn as RBE backends, but
only one at a time per deployment.

**Rationale**:
- Buildfarm: simpler architecture, official Helm chart, Java ecosystem,
  good for teams that want fewer moving parts.
- Buildbarn: more modular, Go ecosystem, block-based self-cleaning CAS,
  better privilege separation (worker/runner split), supports more build
  systems (Buck2, Reninja, Pants, recc). Better for teams that want
  fine-grained scaling control.
- Both implement the same Remote Execution API v2, so Bazel, Buck2, and
  Reninja clients can target either backend.

---

## DD-005: Cluster Profiles via Values Files

**Decision**: Provide pre-built values files ("cluster profiles") for common
Kubernetes cluster configurations.

**Rationale**:
- Different clusters use different CNIs, ingress controllers, and storage
  classes. Rather than requiring operators to understand every toggle, we
  provide tested profiles:
  - `calico-contour.yaml` -- Calico CNI + Contour ingress (on-prem typical)
  - `calico-gateway-api.yaml` -- Calico CNI + Gateway API (modern on-prem)
  - `cilium-gateway-api.yaml` -- Cilium CNI + Gateway API
  - `gke.yaml` -- GKE with standard networking
  - `eks.yaml` -- EKS with AWS ALB + Calico
  - `vanilla.yaml` -- Standard k8s NetworkPolicy + nginx ingress (minimal)

---

## DD-006: Network Policy Generation

**Decision**: Generate NetworkPolicy resources from the chart for all
deployed components, with support for both standard Kubernetes and Calico
policies.

**Rationale**:
- Many production clusters enforce "deny-all-by-default" network policies.
  If we don't ship policies, the components cannot communicate.
- Calico policies add value (ordered evaluation, deny rules, logging).
- Standard k8s policies work with any CNI.
- The inter-component traffic matrix is fully known at chart render time.

**Implementation**:
- `cluster.networkPolicy.enabled: true` (default)
- `cluster.networkPolicy.provider: calico | kubernetes`
- Templates iterate over enabled components and generate the minimum
  required allow rules.

---

## DD-007: Ingress Abstraction Layer

**Decision**: Abstract ingress behind a provider selector rather than
hardcoding one ingress type.

**Rationale**:
- gRPC services require HTTP/2-aware ingress. Not all ingress controllers
  handle this equally.
- Contour HTTPProxy with `protocol: h2c` is the most battle-tested for
  gRPC on-prem.
- Gateway API `GRPCRoute` is the future standard but not universally
  available yet.
- nginx Ingress works but requires specific annotations for gRPC.

**Implementation**:
- `cluster.ingress.provider: contour | gateway-api | nginx`
- Templates in `infrastructure/ingress/` select the right resource type.
- All modes integrate with cert-manager for TLS.

---

## DD-008: TLS Everywhere via cert-manager

**Decision**: Use cert-manager for all TLS certificate management.

**Rationale**:
- gRPC clients strongly prefer TLS (`grpcs://`).
- cert-manager is the de-facto standard for certificate lifecycle in k8s.
- Supports both public CAs (Let's Encrypt) and internal CAs.
- Integrates natively with Contour, Gateway API, and nginx.

**Implementation**:
- `global.tls.enabled: true` (default)
- `global.tls.issuerRef` references a ClusterIssuer or Issuer.
- Chart generates `Certificate` resources for each exposed service.

---

## DD-009: Buildbarn Helm Chart (New)

**Decision**: Create a new Helm chart for Buildbarn since no official one
exists.

**Rationale**:
- Buildbarn only provides Kustomize manifests and Docker Compose files.
- The third-party chart (slamdev/buildbarn v0.0.1) is unmaintained.
- A proper Helm chart with configurable values is needed for the umbrella
  chart pattern.
- The chart will mirror the structure of the official bb-deployments
  Kubernetes manifests but add Helm templating.

**Components to template**:
- `bb-storage` frontend (Deployment + Service)
- `bb-storage` shards (StatefulSet + Service + PVC)
- `bb-scheduler` (Deployment + Service)
- `bb-worker` + `bb-runner` (Deployment with sidecar pattern)
- `bb-browser` (Deployment + Service, optional)
- ConfigMaps from Jsonnet → JSON

---

## DD-010: Observability Stack Integration

**Decision**: Generate `ServiceMonitor` CRDs for Prometheus Operator but do
NOT deploy Prometheus/Grafana.

**Rationale**:
- Most production clusters already have a monitoring stack.
- Deploying another Prometheus would conflict.
- ServiceMonitors are the standard integration point.
- Optional Grafana dashboard ConfigMaps let operators import dashboards.

---

## DD-011: Storage Class Abstraction

**Decision**: Let operators specify storage classes via values rather than
hardcoding.

**Rationale**:
- Storage classes vary wildly across clusters (gp3, pd-ssd, local-path,
  longhorn, etc.).
- Buildfarm recommends XFS for CAS (high link count limits).
- Buildbarn uses block-based storage and is less filesystem-sensitive.
- `global.storageClass` provides a default; per-component overrides are
  available.

---

## DD-012: Single RBE Provider at a Time

**Decision**: Only one RBE provider can be active per rek8s deployment.
Attempting to enable both Buildfarm and Buildbarn is a validation error.

**Rationale**:
- Both listen on port 8980 for the REAPI.
- Running both would confuse the ingress routing.
- The Remote Execution API is the same; there is no benefit to running both.
- Validation is enforced via a template assertion.
