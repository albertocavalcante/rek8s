# Major Platform Deployment Guide

This guide collects the first-wave, production-oriented `rek8s` examples for
the major Kubernetes targets we care about now:

- vanilla Kubernetes
- Docker Desktop Kubernetes
- Google Kubernetes Engine (GKE)
- DigitalOcean Kubernetes (DOKS)
- Amazon EKS
- Azure Kubernetes Service (AKS)
- Oracle Kubernetes Engine (OKE)
- Magalu Cloud Kubernetes

These examples assume the same baseline stack unless stated otherwise:

- `bes.buildbuddy.enabled: true`
- `rbe.buildfarm.enabled: true`
- TLS enabled on managed clusters
- BuildBuddy backed by an external MySQL-compatible database before scaling

If you need the simplest baseline first, start with
[`vanilla.yaml`](../examples/cluster-profiles/vanilla.yaml). If you need the
first "real" ingress-backed baseline, start with
[`vanilla-nginx.yaml`](../examples/cluster-profiles/vanilla-nginx.yaml).

## Decision Matrix

| Platform | Profile | Ingress model | Storage class | Network policy mode | Notes |
|----------|---------|---------------|---------------|---------------------|-------|
| Vanilla Kubernetes | [`vanilla-nginx.yaml`](../examples/cluster-profiles/vanilla-nginx.yaml) | `ingress-nginx` | cluster default | standard k8s | Good generic on-prem baseline |
| Docker Desktop | [`docker-desktop.yaml`](../examples/cluster-profiles/docker-desktop.yaml) | none | cluster default | disabled | Local-only, port-forward first |
| GKE | [`gke.yaml`](../examples/cluster-profiles/gke.yaml) | Gateway API | `premium-rwo` | standard k8s | Best fit when Gateway API is available |
| DigitalOcean | [`digitalocean.yaml`](../examples/cluster-profiles/digitalocean.yaml) | Gateway API | `do-block-storage` | standard k8s | Uses DOKS + Cilium path |
| Amazon EKS | [`eks.yaml`](../examples/cluster-profiles/eks.yaml) | nginx ingress | `gp3` | standard k8s | Pair ingress-nginx with AWS LB integration |
| Azure AKS | [`aks.yaml`](../examples/cluster-profiles/aks.yaml) | managed nginx ingress | `managed-csi-premium` | standard k8s | Uses AKS application routing |
| Oracle OKE | [`oke.yaml`](../examples/cluster-profiles/oke.yaml) | nginx ingress | `oci-bv` | standard k8s via Calico | OCI LB handled at ingress-controller layer |
| Magalu Cloud | [`magalu-cloud.yaml`](../examples/cluster-profiles/magalu-cloud.yaml) | nginx ingress | `mgc-csi-magalu-sc` | standard k8s | Storage docs are strong; NP support should be verified |

## Shared Guidance

- Buildfarm worker PVCs are hot paths. On every cloud, use SSD-backed block
  storage and budget real IOPS for CAS traffic.
- The chart's `kubernetes` network-policy provider is intentionally
  ingress-focused. It isolates inbound traffic but leaves egress open so cloud
  object storage, managed SQL, ACME, and control-plane integrations still work.
- For nginx-based profiles, cloud-specific load-balancer annotations usually
  belong on the ingress-controller `Service`, not on the `rek8s` app Ingress.
- Gateway API profiles require an existing `Gateway`. `rek8s` currently creates
  `HTTPRoute` and `GRPCRoute`, not the `Gateway` itself.
- BuildBuddy should not be scaled horizontally on SQLite. Move it to managed
  MySQL first.

## Vanilla Kubernetes

Example files:

- [`examples/cluster-profiles/vanilla-nginx.yaml`](../examples/cluster-profiles/vanilla-nginx.yaml)
- [`examples/cluster-profiles/vanilla.yaml`](../examples/cluster-profiles/vanilla.yaml)

Install:

```bash
helm install rek8s ./charts/rek8s \
  -f examples/cluster-profiles/vanilla-nginx.yaml \
  --set global.domain=build.example.com
```

Gotchas:

- Standard Kubernetes only defines the `NetworkPolicy` API. Enforcement depends
  on the installed CNI.
- Do not assume a default `StorageClass` exists. If it does not, PVCs will stay
  pending until you set `global.storageClass`.
- For gRPC endpoints behind nginx, keep `backend-protocol: GRPC` and long proxy
  timeouts in place.

## Docker Desktop Kubernetes

Example file:

- [`examples/cluster-profiles/docker-desktop.yaml`](../examples/cluster-profiles/docker-desktop.yaml)

Install:

```bash
kubectl config use-context docker-desktop
helm install rek8s ./charts/rek8s \
  -f examples/cluster-profiles/docker-desktop.yaml
kubectl port-forward -n rek8s-bes svc/rek8s-buildbuddy 8080:8080 1985:1985
kubectl port-forward -n rek8s-rbe svc/rek8s-buildfarm-server 8980:8980
```

Gotchas:

- Prefer Docker Desktop's `kind` provisioner over `kubeadm`; it supports
  multi-node clusters, version selection, and Enhanced Container Isolation.
- Docker Desktop clusters are not auto-upgraded; resetting the cluster is the
  upgrade path, so treat local state as disposable.
- Local host-backed storage is fine for smoke tests, not for realistic remote
  execution performance work.

## GKE

Example files:

- [`examples/cluster-profiles/gke.yaml`](../examples/cluster-profiles/gke.yaml)
- [`examples/gateways/gke-external-gateway.yaml`](../examples/gateways/gke-external-gateway.yaml)

Install:

```bash
kubectl apply -f examples/gateways/gke-external-gateway.yaml
helm install rek8s ./charts/rek8s \
  -f examples/cluster-profiles/gke.yaml \
  --set global.domain=build.example.com
```

Gotchas:

- The Gateway listener certificate and the per-service TLS secrets generated by
  `cert-manager` are separate concerns. Plan both.
- If you use a Secret-backed listener certificate, create that Secret in the
  Gateway namespace. GKE also supports Certificate Manager certmaps instead.
- `premium-rwo` is the right default for latency-sensitive worker PVCs, but it
  is still zonal block storage; replica placement matters.
- If BuildBuddy uses GCS and Cloud SQL privately, keep egress open or extend
  policy rules deliberately.

## DigitalOcean Kubernetes

Example files:

- [`examples/cluster-profiles/digitalocean.yaml`](../examples/cluster-profiles/digitalocean.yaml)
- [`examples/gateways/doks-cilium-gateway.yaml`](../examples/gateways/doks-cilium-gateway.yaml)

Install:

```bash
kubectl apply -f examples/gateways/doks-cilium-gateway.yaml
helm install rek8s ./charts/rek8s \
  -f examples/cluster-profiles/digitalocean.yaml \
  --set global.domain=build.example.com
```

Gotchas:

- DOKS runs on Cilium, which makes Gateway API and Hubble a good operational
  fit, but you still need to create the `Gateway` explicitly.
- Managed Gateway API is enabled by default only on VPC-native DOKS clusters
  running Kubernetes 1.33 or later.
- If you terminate TLS at the Gateway, DigitalOcean requires the
  `do-loadbalancer-tls-passthrough` annotation and the TLS Secret must live in
  the same namespace as the `Gateway`.
- `do-block-storage` is `ReadWriteOnce`; every worker gets its own PVC.
- If you keep BuildBuddy state on block storage, treat node failure and volume
  reattachment times as part of your recovery budget.

## Amazon EKS

Example file:

- [`examples/cluster-profiles/eks.yaml`](../examples/cluster-profiles/eks.yaml)

Install:

```bash
helm install rek8s ./charts/rek8s \
  -f examples/cluster-profiles/eks.yaml \
  --set global.domain=build.example.com
```

Gotchas:

- Install the Amazon EBS CSI add-on before using `gp3`, and grant it AWS IAM
  permissions. Otherwise PVC provisioning fails with `UnauthorizedOperation`.
- Decide early whether you want EKS Pod Identity or IRSA for cloud access.
- Standard `NetworkPolicy` enforcement in EKS is limited to Amazon EC2 Linux
  nodes, and EKS requires service port and container port to match.
- Put AWS load-balancer annotations on the ingress-controller `Service`; the app
  Ingress should stay focused on routing.

## Azure Kubernetes Service

Example file:

- [`examples/cluster-profiles/aks.yaml`](../examples/cluster-profiles/aks.yaml)

Install:

```bash
helm install rek8s ./charts/rek8s \
  -f examples/cluster-profiles/aks.yaml \
  --set global.domain=build.example.com
```

Gotchas:

- The AKS application routing add-on requires a managed identity cluster.
- Microsoft states the managed NGINX path remains supported through November
  2026 while they steer users toward the Gateway API implementation.
- Microsoft does not support editing the managed ingress-nginx `ConfigMap` in
  the `app-routing-system` namespace, so do not build a deployment plan that
  depends on controller-level nginx tweaks.
- `managed-csi-premium` is a better starting point than the cheaper defaults
  for Buildfarm worker disks.

## Oracle Kubernetes Engine

Example file:

- [`examples/cluster-profiles/oke.yaml`](../examples/cluster-profiles/oke.yaml)

Install:

```bash
helm install rek8s ./charts/rek8s \
  -f examples/cluster-profiles/oke.yaml \
  --set global.domain=build.example.com
```

Gotchas:

- OCI load-balancer behavior is usually configured on the ingress-controller
  `Service`, plus network security lists / NSGs outside the chart.
- If you want `NetworkPolicy` enforcement on OKE, install Calico. Oracle
  documents both full Calico and Calico policy-only setups.
- `oci-bv` is the standard block-volume baseline; worker PVC locality still
  follows node placement.
- Keep the first OKE example boring: nginx ingress, block storage, and an
  external database. Avoid mixing in too many OCI-specific features at once.

## Magalu Cloud Kubernetes

Example file:

- [`examples/cluster-profiles/magalu-cloud.yaml`](../examples/cluster-profiles/magalu-cloud.yaml)

Install:

```bash
helm install rek8s ./charts/rek8s \
  -f examples/cluster-profiles/magalu-cloud.yaml \
  --set global.domain=build.example.com
```

Gotchas:

- On Magalu Cloud platform v3, the default storage class is
  `mgc-csi-magalu-sc`, backed by `block.csi.magalu.cloud`.
- That default class uses `Retain`, so deleting a PVC does not automatically
  delete the underlying block volume.
- It also uses `WaitForFirstConsumer`, which is correct for multi-AZ clusters
  but surprises teams expecting immediate volume creation.
- Magalu's storage documentation is clear; its Kubernetes docs are less explicit
  about NetworkPolicy enforcement details. Validate policy behavior in-cluster
  before treating it as a hard security boundary.

## Sources

These profiles and gotchas were aligned against current primary sources on
March 22, 2026.

- Kubernetes network policies: <https://kubernetes.io/docs/concepts/services-networking/network-policies/>
- Kubernetes storage classes: <https://kubernetes.io/docs/concepts/storage/storage-classes/>
- ingress-nginx gRPC support: <https://kubernetes.github.io/ingress-nginx/examples/grpc/>
- Docker Desktop Kubernetes: <https://docs.docker.com/desktop/use-desktop/kubernetes/>
- GKE Gateway API: <https://cloud.google.com/kubernetes-engine/docs/how-to/deploying-gateways>
- GKE Dataplane V2: <https://cloud.google.com/kubernetes-engine/docs/concepts/dataplane-v2>
- GKE SSD persistent disks: <https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/ssd-pd>
- Amazon EKS network policy: <https://docs.aws.amazon.com/eks/latest/userguide/cni-network-policy.html>
- Amazon EKS EBS CSI: <https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html>
- Amazon EKS AWS Load Balancer Controller: <https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html>
- Amazon EKS Pod Identity: <https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html>
- Azure AKS application routing: <https://learn.microsoft.com/en-us/azure/aks/app-routing>
- Azure AKS Azure CNI powered by Cilium: <https://learn.microsoft.com/en-us/azure/aks/azure-cni-powered-by-cilium>
- Azure AKS CSI disk provisioning: <https://learn.microsoft.com/en-us/azure/aks/azure-csi-disk-storage-provision>
- DigitalOcean Gateway API: <https://docs.digitalocean.com/products/kubernetes/how-to/use-gateway-api/>
- DigitalOcean block storage volumes: <https://docs.digitalocean.com/products/kubernetes/how-to/add-volumes/>
- DigitalOcean Hubble / Cilium: <https://docs.digitalocean.com/products/kubernetes/how-to/use-cilium-hubble/>
- Magalu Cloud load balancers: <https://docs.magalu.cloud/docs/containers-manager/kubernetes/how-to/load-balancers/overview/>
- Magalu Cloud persistent volumes: <https://docs.magalu.cloud/docs/containers-manager/kubernetes/how-to/persistent-volumes/overview/>
- Magalu Cloud storage class details: <https://docs.magalu.cloud/docs/containers-manager/kubernetes/how-to/persistent-volumes/storage-class/>
- Oracle OKE ingress controllers: <https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengmanagingresscontrollers.htm>
- Oracle OKE nginx ingress example: <https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengsettingupingresscontroller.htm>
- Oracle OKE block volume PVCs: <https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengcreatingpersistentvolumeclaim_topic-Provisioning_PVCs_on_BV.htm>
- Oracle OKE Calico policies: <https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengsettingupcalico.htm>
- Oracle OKE load balancer services: <https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengcreatingloadbalancer.htm>
