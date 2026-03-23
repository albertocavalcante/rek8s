# Platform Support Tracks

Not every Kubernetes platform should be expressed as a simple cluster profile.
This document separates platforms that fit the current `rek8s` chart shape from
platforms that need a different support model.

## Direct Profile Platforms

These platforms map well to the current chart:

- vanilla Kubernetes
- Docker Desktop Kubernetes
- GKE
- DOKS
- EKS
- AKS
- OKE
- Magalu Cloud
- Vultr VKE
- Akamai / Linode LKE
- Scaleway Kapsule
- IBM Cloud Kubernetes Service (VPC)
- Alibaba ACK via the managed NGINX path

Common characteristics:

- standard Kubernetes APIs are the primary integration point
- ingress is either Gateway API or user-installed `ingress-nginx`
- storage is exposed through ordinary PVC-backed storage classes
- no platform-specific security API must be modeled directly in the chart

## Managed OpenShift Track

Platforms:

- ROSA
- ARO
- OSD / OpenShift variants

Why this is a separate track:

- OpenShift introduces Routes as a first-class north-south entry point.
- SCCs and the OpenShift security model can affect upstream charts even when
  manifests are valid Kubernetes.
- Operators and cluster-managed controllers are more central to the platform
  story than on the vanilla managed-Kubernetes providers.

Recommended support model:

1. Compatibility guide added in [`openshift-compatibility.md`](./openshift-compatibility.md).
2. Decide whether `rek8s` should support Routes directly or standardize on
   Ingress / Gateway API and document the tradeoff.
3. Validate subcharts against restricted SCC expectations before publishing
   OpenShift profiles.

## Alibaba ACK Advanced Ingress Track

Platform:

- Alibaba Cloud ACK

What is directly supported now:

- standard Kubernetes `Ingress` routed by the ACK-managed NGINX Ingress
  Controller
- Terway-backed standard Kubernetes `NetworkPolicy`
- CSI-backed disk volumes through explicit ACK StorageClasses

Why this remains a separate advanced track:

- ACK supports both managed NGINX and Alibaba-specific ALB/APIG ingress paths.
- Load-balancer defaults changed in 2025 toward NLB for new services and new
  NGINX ingress-controller installs.
- ACK has several storage and ingress combinations that deserve an intentional
  opinion instead of collapsing everything into one profile.

Recommended support model:

1. Keep the current ACK profile focused on managed NGINX.
2. Treat these as separate advanced ACK tracks:
   - ALB Ingress
   - APIG / Higress
   - ACK One multi-cluster ingress
3. Only add direct chart integration when `rek8s` can model the provider API
   cleanly instead of hiding it behind generic annotations.

## Distribution Track

Platforms:

- RKE2
- k3s
- Talos Linux
- Cluster API installs
- vSphere-backed clusters
- Proxmox-backed clusters

Directly supported now:

- `k3s-traefik-gateway.yaml`
- `rke2-traefik-gateway.yaml`
- `talos-cilium-gateway.yaml`
- `cilium-gateway-api.yaml`

Why separate:

- These are distribution environments rather than cloud products.
- The main differences are around CNI, storage, ingress controller, and node
  operating model, not cloud-controller integration.

Recommended support model:

- document them as “distribution profiles”
- prefer Gateway API when the distribution already ships Traefik
- use Cilium Gateway API when the distribution documents Cilium as the primary
  advanced networking path
- keep the values files simple and focused on ingress/CNI/storage assumptions

## Cluster API And Virtualization Track

Platforms:

- Cluster API workload clusters
- vSphere-backed clusters
- Proxmox-backed clusters

Guide:

- [`cluster-api-virtualization.md`](./cluster-api-virtualization.md)

Why this is a separate support track:

- Cluster API manages lifecycle, but does not choose ingress, network policy,
  or storage for `rek8s`.
- Hypervisors like vSphere and Proxmox affect provisioning and load-balancer
  availability, but do not by themselves define the correct chart profile.

Recommended support model:

- reuse runtime profiles such as `cilium-gateway-api`, `calico-gateway-api`,
  `talos-cilium-gateway`, and `vanilla-nginx`
- add a new direct profile only when the platform changes chart behavior in a
  way the generic runtime profiles cannot express

## Sources

- Cluster API provider list: <https://main.cluster-api.sigs.k8s.io/reference/providers>
- Cluster API version support: <https://main.cluster-api.sigs.k8s.io/reference/versions>
- Cluster API kubeadm bootstrap: <https://main.cluster-api.sigs.k8s.io/tasks/bootstrap/kubeadm-bootstrap/>
- Cluster API Provider vSphere: <https://github.com/kubernetes-sigs/cluster-api-provider-vsphere>
- Cluster API Provider Proxmox: <https://github.com/k8s-proxmox/cluster-api-provider-proxmox>
- Talos deploying Cilium: <https://www.talos.dev/latest/kubernetes-guides/network/deploying-cilium/>
- Talos KubePrism: <https://www.talos.dev/v1.8/kubernetes-guides/configuration/kubeprism/>
- Talos ingress firewall: <https://www.talos.dev/v1.11/talos-guides/network/ingress-firewall/>
- Talos process capabilities: <https://www.talos.dev/v1.6/learn-more/process-capabilities/>
- Cilium Gateway API support: <https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/>
- K3s packaged components: <https://docs.k3s.io/installation/packaged-components>
- K3s networking services: <https://docs.k3s.io/networking/networking-services>
- K3s Helm customization: <https://docs.k3s.io/add-ons/helm>
- RKE2 networking services: <https://docs.rke2.io/networking/networking_services>
- RKE2 basic network options: <https://docs.rke2.io/networking/basic_network_options>
- RKE2 Helm customization: <https://docs.rke2.io/add-ons/helm>
- Traefik Gateway API provider: <https://doc.traefik.io/traefik/reference/install-configuration/providers/kubernetes/kubernetes-gateway/>
- IBM Cloud VPC load balancers: <https://cloud.ibm.com/docs/containers?topic=containers-vpclb-about>
- IBM Cloud Kubernetes network policies: <https://cloud.ibm.com/docs/containers?topic=containers-network_policies>
- IBM Cloud block storage for VPC: <https://cloud.ibm.com/docs/containers?topic=containers-storage-block-vpc-sc-ref>
- Alibaba ACK high-risk operations: <https://www.alibabacloud.com/help/en/ack/product-overview/before-you-start>
- Alibaba ACK service FAQ: <https://www.alibabacloud.com/help/en/ack/ack-managed-and-ack-dedicated/user-guide/service-faq>
- Alibaba ACK ALB Ingress management: <https://www.alibabacloud.com/help/en/slb/application-load-balancer/user-guide/alb-ingress/>
- Alibaba ACK load balancer behavior change notice: <https://www.alibabacloud.com/en/notice/ack_load_balancer_type_and_billing_method_change_for_new_services_and_nginx_ingress_controller_53b?_p_lc=1>
- Red Hat OpenShift Service on AWS intro: <https://docs.redhat.com/en/documentation/red_hat_openshift_service_on_aws/4/pdf/introduction_to_rosa/red_hat_openshift_service_on_aws-4-introduction_to_rosa-en-us.pdf>
- Azure Red Hat OpenShift overview: <https://learn.microsoft.com/en-us/azure/openshift/intro-openshift>
- Azure Red Hat OpenShift infrastructure nodes: <https://learn.microsoft.com/en-us/azure/openshift/howto-infrastructure-nodes>
