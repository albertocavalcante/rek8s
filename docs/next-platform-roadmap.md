# Next Platform Roadmap

This document tracks the next expansion wave beyond the first set of major
`rek8s` platform profiles.

## Immediate Adds

These platforms map cleanly to the current chart without introducing a new
ingress abstraction, security model, or storage integration layer.

### Vultr Kubernetes Engine (VKE)

Status: added in [`vultr-vke.yaml`](../examples/cluster-profiles/vultr-vke.yaml)

Why it fits:

- Vultr documents VKE as a managed Kubernetes service.
- VKE uses Calico as the default CNI.
- VKE does not include a preconfigured ingress controller, which matches the
  `rek8s` pattern of installing `ingress-nginx` explicitly.
- VKE integrates with Vultr load balancers and Vultr CSI-backed storage.

Main gotchas:

- Use `vultr-block-storage` for NVMe-backed worker PVCs when the region supports
  it; `vultr-block-storage-hdd` exists but is not a good default for CAS-heavy
  Buildfarm workers.
- Vultr block storage is `ReadWriteOnce`; shared-write use cases require
  `vultr-vfs-storage`, which is outside the current Buildfarm-first path.

### Akamai Cloud / Linode Kubernetes Engine (LKE)

Status: added in [`linode-lke.yaml`](../examples/cluster-profiles/linode-lke.yaml)

Why it fits:

- LKE is a managed Kubernetes platform with a managed Cloud Controller Manager.
- `LoadBalancer` services create managed NodeBalancers.
- Linode Block Storage CSI is present and supports standard Kubernetes PVC
  flows.

Main gotchas:

- Use `linode-block-storage` for normal PVC deletion behavior and
  `linode-block-storage-retain` only when you explicitly want retained disks.
- Akamai recommends moving application data off local node filesystems and into
  Persistent Volumes before maintenance events.
- Cloud Firewall Controller is worth documenting alongside the profile, but it
  stays outside the `rek8s` chart.

### Scaleway Kubernetes Kapsule

Status: added in [`scaleway-kapsule.yaml`](../examples/cluster-profiles/scaleway-kapsule.yaml)

Why it fits:

- Kapsule is a managed Kubernetes engine with block-volume-backed PVC support.
- Scaleway supports `cilium` and `calico`, both of which are compatible with
  standard Kubernetes `NetworkPolicy`.
- Scaleway explicitly allows you to deploy the ingress controller of your
  choice.

Main gotchas:

- Rely on the cluster's default Block Volume StorageClass unless you have a
  reason to customize storage classes directly.
- Kapsule nodes are explicitly stateless; stateful workloads should always use
  PVCs.
- Scaleway automatically upgrades unsupported minors after the support window,
  so version pinning should be revisited regularly.

## Second Wave

These are worth supporting next, but they need more provider-specific work than
the immediate adds above.

### IBM Cloud Kubernetes Service

Status: added in [`ibm-cloud-vpc.yaml`](../examples/cluster-profiles/ibm-cloud-vpc.yaml)

Why it graduated:

- IBM documents VPC load balancers created from Kubernetes `LoadBalancer`
  services.
- IBM documents standard Kubernetes network policies and Calico advanced
  policies.
- IBM provides a clear VPC block-storage class reference, including
  `ibmc-vpc-block-10iops-tier`.

### Alibaba Cloud ACK

Status: added in [`alibaba-ack.yaml`](../examples/cluster-profiles/alibaba-ack.yaml)

Why it graduated:

- ACK documents a clean managed NGINX Ingress path for standard Kubernetes
  Ingress resources.
- ACK documents a recommended topology-aware disk StorageClass:
  `alicloud-disk-topology-alltype`.
- ACK documents Terway-based support for standard Kubernetes `NetworkPolicy`.

Remaining advanced track:

- ALB Ingress
- APIG / Higress
- ACK One multi-cluster ingress

## Separate Track: OpenShift

These should not be treated as ordinary managed-Kubernetes profiles.

### ROSA
### ARO
### OSD / OpenShift on IBM Cloud

Why separate:

- OpenShift introduces Routes, Security Context Constraints, and different
  operational expectations.
- Even if the raw Kubernetes APIs exist, the “right” deployment story is not
  the same as the vanilla/nginx/gateway-api path.

Recommended approach:

- OpenShift support document added in [`openshift-compatibility.md`](./openshift-compatibility.md).
- Decide whether `rek8s` should support OpenShift Routes directly, or continue
  to standardize on Ingress / Gateway API and document the tradeoff.

## Separate Track: Self-Managed Distributions

These are likely valuable, but they are distribution support rather than cloud
support:

### k3s

Status: added in [`k3s-traefik-gateway.yaml`](../examples/cluster-profiles/k3s-traefik-gateway.yaml)

Why it graduated:

- K3s ships packaged Traefik, ServiceLB, local storage, and a built-in
  network-policy controller.
- K3s 1.32+ moved packaged Traefik to v3, which makes the Gateway API path a
  cleaner fit than forcing `ingress-nginx`.

Main gotchas:

- The default `local-path` storage is node-local, so HA state still needs a
  stronger storage backend.
- ServiceLB consumes ports 80 and 443 on participating nodes.

### RKE2

Status: added in [`rke2-traefik-gateway.yaml`](../examples/cluster-profiles/rke2-traefik-gateway.yaml)

Why it graduated:

- RKE2 documents Traefik support directly and exposes packaged Traefik through
  `HelmChartConfig`.
- As of March 22, 2026, RKE2 documents `ingress-nginx` as end-of-life in March
  2026 and says new v1.36 clusters default to Traefik.

Main gotchas:

- Storage remains environment-specific, so the profile intentionally uses the
  cluster default StorageClass.
- Standard Kubernetes `NetworkPolicy` depends on using Canal, Calico, or
  Cilium instead of Flannel.

### Talos Linux

Status: added in [`talos-cilium-gateway.yaml`](../examples/cluster-profiles/talos-cilium-gateway.yaml)

Why it graduated:

- Talos documents a clear Cilium installation path and explicitly documents the
  bootstrap requirements.
- Cilium Gateway API support is mature enough to fit the existing `rek8s`
  Gateway API mode without adding provider-specific chart logic.

Main gotchas:

- Talos Cilium bootstrap starts with `cluster.network.cni.name: none`, so the
  cluster looks unhealthy until Cilium is installed.
- On bare metal, a Cilium Gateway may have no external address until you add a
  load-balancer implementation or use Cilium host-network mode.
- Storage remains external to Talos itself, so the profile intentionally
  expects a default StorageClass supplied by the operator.

Remaining distribution candidates:

- Cluster API-based installs
- vSphere-backed clusters
- Proxmox-backed clusters

These should eventually expand beyond the first Traefik-based distribution
profiles into a broader “distribution profiles” section.

## Sources

- Vultr Kubernetes overview: <https://docs.vultr.com/products/kubernetes>
- Vultr ingress controller FAQ: <https://docs.vultr.com/support/products/vke/does-vke-come-with-an-ingress-controller>
- Vultr persistent storage FAQ: <https://docs.vultr.com/support/products/vke/how-does-vultr-kubernetes-engine-handle-persistent-data-storage>
- Vultr PVC guide: <https://docs.vultr.com/how-to-provision-persistent-volume-claims-on-vultr-kubernetes-engine>
- Akamai Cloud getting started: <https://techdocs.akamai.com/cloud-computing/docs/getting-started>
- Akamai LKE load balancing: <https://techdocs.akamai.com/cloud-computing/docs/get-started-with-load-balancing-on-an-lke-cluster>
- Akamai Block Storage: <https://techdocs.akamai.com/cloud-computing/docs/block-storage>
- Akamai LKE firewall details: <https://techdocs.akamai.com/cloud-computing/docs/lke-network-firewall-details>
- Scaleway Kubernetes docs: <https://www.scaleway.com/en/docs/kubernetes/>
- Scaleway Kubernetes API: <https://www.scaleway.com/en/developers/api/kubernetes/>
- Scaleway version support policy: <https://www.scaleway.com/en/docs/kubernetes/reference-content/version-support-policy//>
- Scaleway Kapsule overview: <https://www.scaleway.com/en/kubernetes-kapsule/>
- IBM Cloud Kubernetes load balancers: <https://cloud.ibm.com/docs/containers?topic=containers-vpclb-about>
- IBM Cloud Kubernetes network policies: <https://cloud.ibm.com/docs/containers?topic=containers-network_policies>
- IBM Cloud Kubernetes block storage: <https://cloud.ibm.com/docs/containers?topic=containers-block_storage>
- K3s packaged components: <https://docs.k3s.io/installation/packaged-components>
- K3s networking services: <https://docs.k3s.io/networking/networking-services>
- K3s Helm customization: <https://docs.k3s.io/add-ons/helm>
- K3s release notes: <https://docs.k3s.io/release-notes/v1.34.X>
- RKE2 networking services: <https://docs.rke2.io/networking/networking_services>
- RKE2 basic network options: <https://docs.rke2.io/networking/basic_network_options>
- RKE2 Helm customization: <https://docs.rke2.io/add-ons/helm>
- Traefik Gateway API provider: <https://doc.traefik.io/traefik/reference/install-configuration/providers/kubernetes/kubernetes-gateway/>
- Talos deploying Cilium: <https://www.talos.dev/latest/kubernetes-guides/network/deploying-cilium/>
- Talos KubePrism: <https://www.talos.dev/v1.8/kubernetes-guides/configuration/kubeprism/>
- Talos ingress firewall: <https://www.talos.dev/v1.11/talos-guides/network/ingress-firewall/>
- Cilium Gateway API support: <https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/>
