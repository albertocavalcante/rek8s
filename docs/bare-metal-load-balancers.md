# Bare-Metal Load Balancers

Several `rek8s` profiles assume that some component in the cluster can satisfy
`Service type=LoadBalancer`:

- Cilium Gateway API paths
- Traefik Gateway API paths when not using K3s ServiceLB
- ingress-nginx paths on self-managed clusters

Cloud profiles get that from the cloud controller. Bare-metal and
virtualization-backed clusters usually do not.

This guide records the first supported answer for that gap:

- MetalLB in layer 2 mode

It also records the main documented fallback for Cilium:

- Cilium Gateway API host-network mode

## When You Need This

You likely need this guide if:

- your `Gateway` or ingress controller never gets an external IP
- your `LoadBalancer` service stays in `pending`
- you are running `rek8s` on Talos, kubeadm, Cluster API, vSphere, or Proxmox

## MetalLB Layer 2

MetalLB documents itself as a bare-metal load-balancer for Kubernetes and says
that after installation you expose services by creating them with
`spec.type: LoadBalancer`.

Layer 2 mode is the safest first recommendation because MetalLB documents it as
the most universal mode: it works on ordinary Ethernet networks without
requiring BGP-capable routers.

Important limitations from MetalLB:

- Layer 2 is a failover mechanism, not true multi-node load balancing.
- All traffic for a service IP lands on one leader node at a time.
- Failover can be slower than ideal because clients depend on ARP/NDP
  convergence.

## Install MetalLB

MetalLB documents three supported install methods. The simplest first pass is
the native manifest:

```bash
# Replace <release> with the current MetalLB release from the installation docs.
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/<release>/config/manifests/metallb-native.yaml
```

MetalLB documents that:

- it installs into `metallb-system`
- the CRs must be created in the same namespace where MetalLB is installed

If you use kube-proxy in IPVS mode, MetalLB also documents that `strictARP`
must be enabled.

## Configure A Public Pool

Example config:

- [`examples/metallb/l2-public-pool.yaml`](../examples/metallb/l2-public-pool.yaml)

Apply it:

```bash
kubectl apply -f examples/metallb/l2-public-pool.yaml
```

Replace the example address range with:

- real free IPs on your LAN, or
- a routed subnet assigned to the cluster nodes

## How This Fits `rek8s`

Once MetalLB is running and configured:

- a `LoadBalancer` service created by ingress-nginx can receive an external IP
- a `LoadBalancer` service created by Traefik can receive an external IP
- a `LoadBalancer` service created by Cilium Gateway API can receive an
  external IP

This is the missing piece for several self-managed examples:

- [`cilium-gateway-api.yaml`](../examples/cluster-profiles/cilium-gateway-api.yaml)
- [`talos-cilium-gateway.yaml`](../examples/cluster-profiles/talos-cilium-gateway.yaml)
- [`rke2-traefik-gateway.yaml`](../examples/cluster-profiles/rke2-traefik-gateway.yaml)

## Cilium Alternative: Host Network Mode

Cilium documents a second option for Gateway API environments: host-network
mode.

Important Cilium details:

- host-network mode is supported since Cilium 1.16
- enabling host-network mode disables the `LoadBalancer` service mode
- listeners are exposed directly on node interfaces
- listener ports must be unique per `Gateway` and should be higher than `1023`

Use this when:

- you do not have a `LoadBalancer` implementation yet
- you are in a lab or dev environment
- you can tolerate binding the Gateway directly on node addresses

Do not treat it as identical to MetalLB:

- MetalLB preserves the usual `LoadBalancer` service workflow
- host-network mode changes the exposure model completely

## What We Are Not Standardizing Yet

This repo does not yet ship a first-class example for:

- MetalLB BGP mode
- FRR-backed MetalLB mode
- Cilium LB-IPAM
- kube-vip as a general-purpose service load balancer

Those are real options, but they require more network-specific assumptions than
the current repo examples should hide.

For control-plane VIPs and the narrower kube-vip service story, see
[`kube-vip.md`](./kube-vip.md).

## Sources

- MetalLB overview: <https://metallb.io/>
- MetalLB installation: <https://metallb.io/installation/>
- MetalLB configuration: <https://metallb.io/configuration/>
- MetalLB usage: <https://metallb.io/usage/index.html>
- MetalLB layer 2 concepts: <https://metallb.io/concepts/layer2/>
- Cilium Gateway API support: <https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/>
