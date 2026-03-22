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

1. Add an OpenShift compatibility guide first.
2. Decide whether `rek8s` should support Routes directly or standardize on
   Ingress / Gateway API and document the tradeoff.
3. Validate subcharts against restricted SCC expectations before publishing
   OpenShift profiles.

## Alibaba ACK Track

Platform:

- Alibaba Cloud ACK

Why this is a separate track for now:

- ACK supports both self-managed `nginx-ingress` and managed ALB Ingresses.
- Load-balancer defaults changed in 2025 toward NLB for new services and new
  NGINX ingress-controller installs.
- ACK has several storage and ingress combinations that deserve an intentional
  first opinion rather than a generic nginx clone.

Recommended support model:

1. Decide whether the first ACK path should be:
   - `nginx-ingress` on managed NLB
   - ALB Ingress
   - Gateway-style cloud-native path later
2. Write one ACK-specific deployment guide before adding a profile.
3. Treat ACK One and multi-cluster ALB use cases as a separate advanced topic.

## Distribution Track

Platforms:

- RKE2
- k3s
- Talos Linux
- Cluster API installs
- vSphere-backed clusters
- Proxmox-backed clusters

Why separate:

- These are distribution environments rather than cloud products.
- The main differences are around CNI, storage, ingress controller, and node
  operating model, not cloud-controller integration.

Recommended support model:

- document them as “distribution profiles”
- keep the values files simple and focused on ingress/CNI/storage assumptions

## Sources

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
