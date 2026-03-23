# kube-vip

This guide covers the two kube-vip roles that matter for `rek8s` users on
self-managed and virtualization-backed clusters:

- highly available control-plane VIPs
- optional `Service type=LoadBalancer` exposure on on-prem clusters

As of March 22, 2026, the recommended mental model is:

- use `kube-vip` first for the Kubernetes API control-plane endpoint
- use MetalLB first for general `rek8s` ingress and Gateway exposure
- use kube-vip service mode only when you intentionally want kube-vip to own
  `LoadBalancer` address assignment and advertisement

## What kube-vip Does

kube-vip documents itself as providing:

- a virtual IP and load balancer for the Kubernetes control plane
- `LoadBalancer` support for Kubernetes Services without external hardware or
  software

It supports both ARP and BGP for control-plane and service advertisement.

## Control Plane First

The most mature first use for kube-vip in this repo is the control-plane VIP.

kube-vip documents the static-Pod kubeadm flow as:

1. generate the kube-vip manifest into the static Pod manifest directory
2. run `kubeadm init --control-plane-endpoint <VIP>`
3. let kubelet start kube-vip and the other control-plane components
4. copy the kube-vip manifest to the other control-plane nodes

Important kube-vip details:

- `--controlplane` enables the HA control-plane VIP behavior
- `--services` enables `LoadBalancer` service watching
- the same manifest can enable both, but they are logically separate features

Practical recommendation:

- for Proxmox, Cluster API on Proxmox, or kubeadm-on-VMware style installs,
  treat kube-vip as the default answer for the control-plane endpoint first
- do not assume that means it should also be your service load balancer

## Service LoadBalancer Mode

kube-vip documents two parts for on-prem service exposure:

- kube-vip itself advertises service addresses
- kube-vip-cloud-provider assigns IPs to `LoadBalancer` Services

The kube-vip cloud provider documents that it:

- only implements the `loadBalancer` part of the out-of-tree cloud-provider
  contract
- updates `kube-vip.io/loadbalancerIPs` and, for now, `spec.loadBalancerIP`
- allocates from CIDR or range pools stored in a `ConfigMap`

## Example Global Pool

Example config:

- [`examples/kube-vip/cloud-provider-global-pool.yaml`](../examples/kube-vip/cloud-provider-global-pool.yaml)

Apply it:

```bash
kubectl apply -f examples/kube-vip/cloud-provider-global-pool.yaml
```

Replace the range with real addresses that belong to your network.

## ARP Gotchas

kube-vip documents several ARP caveats that matter for `rek8s` users:

- in ARP mode, control-plane leadership selects one node to hold the VIP
- for services, kube-vip supports either one leader for all services or an
  election per service
- the default “one leader for all services” mode can become a bottleneck
- the VIP can be mistaken for the node InternalIP unless kubelet `--node-ip` is
  set correctly
- when using Calico, kube-vip documents that autodetection should be aligned to
  the Kubernetes internal node IP so Felix does not pick up the VIP

Practical inference:

- kube-vip is a strong fit for the API VIP
- for many `rek8s` ingress and Gateway use cases, MetalLB remains the simpler
  first recommendation

## DaemonSet Mode

kube-vip also documents a DaemonSet install path.

Important details:

- the DaemonSet path still uses generated manifests
- kube-vip documents a required RBAC manifest for DaemonSet mode
- this is the path you would normally use when watching services inside the
  cluster rather than only providing the static control-plane VIP

## How This Fits `rek8s`

Use kube-vip when you need:

- a stable control-plane endpoint for kubeadm-style HA clusters
- a Proxmox-friendly answer to “what fronts the API server VIP?”

Prefer MetalLB first when you need:

- external IPs for `rek8s` Gateway or ingress services
- a general-purpose `LoadBalancer` workflow for self-managed clusters

See also:

- [`bare-metal-load-balancers.md`](./bare-metal-load-balancers.md)
- [`cluster-api-virtualization.md`](./cluster-api-virtualization.md)

## Sources

- kube-vip overview: <https://kube-vip.io/>
- kube-vip features: <https://kube-vip.io/docs/about/features/>
- kube-vip static Pods: <https://kube-vip.io/docs/installation/static/>
- kube-vip DaemonSet: <https://kube-vip.io/docs/installation/daemonset/>
- kube-vip ARP mode: <https://kube-vip.io/docs/modes/arp/>
- kube-vip on-prem cloud provider: <https://kube-vip.io/docs/usage/cloud-provider/>
- kube-vip cloud provider repo: <https://github.com/kube-vip/kube-vip-cloud-provider>
