# Distribution Profiles

This document covers the first self-managed Kubernetes distributions that fit
the current `rek8s` chart shape without inventing provider-specific APIs:

- K3s with Traefik + Gateway API
- RKE2 with Traefik + Gateway API

These are intentionally routed through Gateway API instead of the older
`ingress-nginx` path. As of March 2026, RKE2 has moved new clusters toward
Traefik, and K3s has shipped Traefik v3 since the Kubernetes 1.32 line.

## Shared Traefik Gateway Path

Install Gateway API CRDs:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml
```

Enable Gateway API in packaged Traefik:

- K3s: [`examples/traefik/k3s-traefik-gateway-config.yaml`](../examples/traefik/k3s-traefik-gateway-config.yaml)
- RKE2: [`examples/traefik/rke2-traefik-gateway-config.yaml`](../examples/traefik/rke2-traefik-gateway-config.yaml)

Create a shared Gateway:

- [`examples/gateways/traefik-public-gateway.yaml`](../examples/gateways/traefik-public-gateway.yaml)

Important details:

- The Traefik Gateway provider must be enabled before `rek8s` `HTTPRoute` and
  `GRPCRoute` objects will attach.
- The example Gateway sets `allowedRoutes.namespaces.from: All` because the
  `rek8s` routes live in multiple namespaces.
- The HTTPS listener uses a placeholder Secret reference; replace it with your
  real certificate Secret in the `rek8s-ingress` namespace.

## K3s

Example file:

- [`examples/cluster-profiles/k3s-traefik-gateway.yaml`](../examples/cluster-profiles/k3s-traefik-gateway.yaml)

Install:

```bash
helm install rek8s ./charts/rek8s \
  -f examples/cluster-profiles/k3s-traefik-gateway.yaml \
  --set global.domain=build.example.com
```

Why this profile looks smaller:

- It keeps BuildBuddy and Buildfarm single-replica on the control plane side.
- It uses `local-path` because that is the packaged K3s storage path.
- It is aimed at serious dev, edge, and homelab clusters, not HA production.

Gotchas:

- K3s packages `traefik`, `local-storage`, `metrics-server`, and CoreDNS, and
  also ships ServiceLB plus the kube-router network-policy controller.
- K3s 1.32 and newer include Traefik v3. Older K3s releases included Traefik
  v2, so this profile should be treated as a K3s 1.32+ path.
- By default, ServiceLB uses all nodes for the Traefik `LoadBalancer` Service,
  which means ports 80 and 443 are not available for other HostPort or
  NodePort workloads.
- `local-path` is node-local storage. If you need durable multi-node state,
  replace it with Longhorn, NFS, or another CSI-backed StorageClass.
- If you replace Flannel with another CNI, K3s documents that you should also
  disable the built-in network-policy controller to avoid conflicts.

## RKE2

Example file:

- [`examples/cluster-profiles/rke2-traefik-gateway.yaml`](../examples/cluster-profiles/rke2-traefik-gateway.yaml)

Install:

```bash
helm install rek8s ./charts/rek8s \
  -f examples/cluster-profiles/rke2-traefik-gateway.yaml \
  --set global.domain=build.example.com
```

Why this profile leaves storage generic:

- RKE2 does not standardize on one storage backend in the same way K3s
  standardizes on `local-path`.
- The values file therefore leaves `global.storageClass` empty and expects the
  cluster default StorageClass to be set intentionally.

Gotchas:

- RKE2 documents `ingress-nginx` as going end-of-life in March 2026 and says
  that starting with v1.36, Traefik is the default for new clusters.
- Traefik support in RKE2 is only available on the August 2024 release line
  and newer. Older RKE2 builds should not use this profile.
- RKE2 ServiceLB is optional, not automatic. If you want bare-metal-style
  `LoadBalancer` behavior without MetalLB or a cloud controller, enable
  ServiceLB explicitly.
- This profile assumes a CNI that enforces standard Kubernetes
  `NetworkPolicy`. That is true for Canal, Calico, and Cilium. RKE2 documents
  that Flannel does not support network policies.

## Sources

- K3s packaged components: <https://docs.k3s.io/installation/packaged-components>
- K3s networking services: <https://docs.k3s.io/networking/networking-services>
- K3s basic network options: <https://docs.k3s.io/networking/basic-network-options>
- K3s HelmChartConfig customization: <https://docs.k3s.io/add-ons/helm>
- K3s current release notes: <https://docs.k3s.io/release-notes/v1.34.X>
- RKE2 networking services: <https://docs.rke2.io/networking/networking_services>
- RKE2 basic network options: <https://docs.rke2.io/networking/basic_network_options>
- RKE2 HelmChartConfig customization: <https://docs.rke2.io/add-ons/helm>
- Traefik Kubernetes Gateway provider: <https://doc.traefik.io/traefik/reference/install-configuration/providers/kubernetes/kubernetes-gateway/>
