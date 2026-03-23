# Cluster API And Virtualization

This document covers the next support family after the cloud and distribution
profiles:

- Cluster API-managed workload clusters
- vSphere-backed clusters
- Proxmox-backed clusters

The key rule is simple:

- `Cluster API`, `vSphere`, and `Proxmox` do not determine the correct `rek8s`
  profile by themselves
- the guest cluster runtime still determines the right `rek8s` profile:
  CNI, ingress model, storage class, and distribution behavior

## Why There Is No `vsphere.yaml`

`rek8s` profiles describe workload-cluster behavior:

- ingress shape
- network-policy mode
- storage assumptions
- TLS and Gateway prerequisites

Cluster API is a lifecycle layer, not an ingress or CNI layer. The Cluster API
book documents the common model as a management cluster running providers that
manage separate workload clusters.

Practical inference:

- a Cluster API workload cluster should reuse an existing `rek8s` runtime
  profile whenever possible
- a hypervisor-backed environment like vSphere or Proxmox only justifies a new
  profile when it changes the guest-cluster networking or storage story in a
  way the chart must model directly

## Recommended Mapping

If your workload cluster uses:

- `Talos + Cilium + Gateway API`
  use [`talos-cilium-gateway.yaml`](../examples/cluster-profiles/talos-cilium-gateway.yaml)
- `kubeadm + Cilium + Gateway API`
  use [`cilium-gateway-api.yaml`](../examples/cluster-profiles/cilium-gateway-api.yaml)
- `kubeadm + Calico + Gateway API`
  use [`calico-gateway-api.yaml`](../examples/cluster-profiles/calico-gateway-api.yaml)
- `kubeadm + ingress-nginx`
  use [`vanilla-nginx.yaml`](../examples/cluster-profiles/vanilla-nginx.yaml)

This applies whether the workload cluster was created:

- manually on vSphere or Proxmox
- by Cluster API on vSphere or Proxmox
- by Talos installation flows on VMware or Proxmox

## Generic Cilium Path

The repo now ships a generic Cilium profile:

- [`cilium-gateway-api.yaml`](../examples/cluster-profiles/cilium-gateway-api.yaml)

It is the right starting point for self-managed virtualization-backed clusters
when:

- Cilium is the CNI
- Gateway API is handled by Cilium
- storage comes from a cluster-default StorageClass

It intentionally uses standard Kubernetes `NetworkPolicy`, not
`CiliumNetworkPolicy`, because that is the policy mode `rek8s` currently
templates.

## vSphere Notes

Cluster API Provider vSphere documents CAPV as declarative infrastructure for
vSphere and notes that it manages VM bootstrapping on vSphere. The CAPV README
also documents published OVAs, but explicitly recommends building and using
custom images for production-like environments.

Practical implications for `rek8s`:

- CAPV is not the ingress choice
- CAPV is not the network-policy choice
- CAPV does not remove the need to pick a real StorageClass and ingress model
- production examples should avoid assuming the stock CAPV images are the final
  operational answer

## Proxmox Notes

Cluster API Provider Proxmox documents itself as an infrastructure provider
only, with bootstrap and control-plane providers supplied separately.
Its README also states that Proxmox VE does not provide LBaaS, and the project
documents preparing the control-plane load balancer yourself, with a kube-vip
HA example.

Practical implications for `rek8s`:

- Proxmox itself does not give you a managed `LoadBalancer` story
- a Proxmox-backed Gateway may not receive an external address until you add
  something like MetalLB, kube-vip for control-plane needs, or another
  environment-specific load-balancer approach
- this is another reason Proxmox should reuse generic runtime profiles instead
  of pretending to be a cloud-style provider profile

See [`bare-metal-load-balancers.md`](./bare-metal-load-balancers.md) for the
first MetalLB-based answer documented in this repo.
See [`kube-vip.md`](./kube-vip.md) for the control-plane VIP path.

## Talos On Proxmox Or VMware

Talos is a special case because Talos does change the guest-cluster operating
model in a meaningful way.

Use:

- [`talos-cilium-gateway.yaml`](../examples/cluster-profiles/talos-cilium-gateway.yaml)

This remains the best fit when the virtualization layer is Proxmox or VMware
but the guest cluster is Talos plus Cilium.

## Recommended Next Work

The next concrete validation step for this support family is:

1. render and test [`cilium-gateway-api.yaml`](../examples/cluster-profiles/cilium-gateway-api.yaml) on one Cluster API workload cluster
2. validate one vSphere-backed runtime
3. validate one Proxmox-backed runtime with an explicit load-balancer strategy
4. only add a new direct profile if the virtualization platform forces chart
   logic that the current generic profiles cannot express

## Sources

- Cluster API provider list: <https://main.cluster-api.sigs.k8s.io/reference/providers>
- Cluster API version support and deployment model: <https://main.cluster-api.sigs.k8s.io/reference/versions>
- Cluster API kubeadm bootstrap: <https://main.cluster-api.sigs.k8s.io/tasks/bootstrap/kubeadm-bootstrap/>
- Cluster API Provider vSphere: <https://github.com/kubernetes-sigs/cluster-api-provider-vsphere>
- Cluster API Provider Proxmox: <https://github.com/k8s-proxmox/cluster-api-provider-proxmox>
- Talos Proxmox guide: <https://www.talos.dev/v1.11/talos-guides/install/virtualized-platforms/proxmox/>
- Talos support matrix: <https://www.talos.dev/v1.9/introduction/support-matrix/>
- Cilium Gateway API support: <https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/>
