# Terraform Blueprints

This document defines the first Terraform support model for `rek8s`.

The goal is not to hide every provider detail behind a single abstraction.
The goal is to provide credible, profile-aligned cluster foundations that map
cleanly to the Helm examples already in this repo.

## Scope

The first Terraform wave focuses on three concrete targets:

- `GKE Gateway` via the upstream
  `terraform-google-modules/kubernetes-engine/google` module
- `EKS nginx` via the upstream `terraform-aws-modules/eks/aws` module
- `DOKS Gateway foundation` via first-party DigitalOcean Terraform resources

These roots live under [`examples/terraform/`](../examples/terraform/).

## Why This Shape

`rek8s` already has mature Helm values profiles for GKE, EKS, and DOKS:

- [`examples/cluster-profiles/gke.yaml`](../examples/cluster-profiles/gke.yaml)
- [`examples/cluster-profiles/eks.yaml`](../examples/cluster-profiles/eks.yaml)
- [`examples/cluster-profiles/digitalocean.yaml`](../examples/cluster-profiles/digitalocean.yaml)

The Terraform roots are designed to create the cluster capabilities those
profiles assume:

- `gke-gateway` enables Dataplane V2, Gateway API, and GCE PD CSI
- `eks-nginx` creates an EKS cluster and the core AWS-managed add-ons that the
  `eks.yaml` profile depends on before the Helm phase
- `doks-gateway` creates a VPC-native DOKS cluster sized for the Gateway API
  path, but intentionally stops before any Kubernetes-provider resources

## Deliberate Non-Goals

The first Terraform wave does not try to do all of the following in one apply:

- create the cluster
- create cloud IAM and storage integrations
- install every Kubernetes add-on
- install `rek8s` itself
- create app-specific databases or object stores

That pattern is too fragile across providers, and in DigitalOcean's case the
provider docs explicitly warn against creating the cluster and Kubernetes
provider resources in the same Terraform module.

## Operating Model

Use Terraform for cluster foundation and provider-shaped prerequisites first.
Then install `rek8s` with the matching Helm values file.

High-level flow:

1. `terraform apply` the provider root under [`examples/terraform/`](../examples/terraform/)
2. fetch cluster credentials
3. install any remaining operator-managed prerequisites such as `cert-manager`
4. create the provider-specific `Gateway` if the profile uses Gateway API
5. `helm install rek8s ./charts/rek8s -f <matching-profile>`

## Current Blueprints

| Blueprint | Terraform path | Matching profile | What it provisions |
|-----------|----------------|------------------|--------------------|
| GKE Gateway | [`examples/terraform/gke-gateway`](../examples/terraform/gke-gateway/) | [`examples/cluster-profiles/gke.yaml`](../examples/cluster-profiles/gke.yaml) | VPC, subnetwork, Dataplane V2 cluster, Gateway API channel, SSD-oriented node pool |
| EKS nginx | [`examples/terraform/eks-nginx`](../examples/terraform/eks-nginx/) | [`examples/cluster-profiles/eks.yaml`](../examples/cluster-profiles/eks.yaml) | VPC, EKS cluster, managed node group, VPC CNI network policy config, EBS CSI |
| DOKS Gateway | [`examples/terraform/doks-gateway`](../examples/terraform/doks-gateway/) | [`examples/cluster-profiles/digitalocean.yaml`](../examples/cluster-profiles/digitalocean.yaml) | VPC-native DOKS cluster, HA control plane, autoscaling worker pool |

## Provider-Specific Decisions

### GKE

The GKE root uses the upstream GKE module because it already models the
cluster features we care about now:

- `datapath_provider`
- `gateway_api_channel`
- `gce_pd_csi_driver`
- node-pool sizing and labels

Important nuance:

- Dataplane V2 provides the standard Kubernetes `NetworkPolicy` behavior that
  the `rek8s` `gke.yaml` profile assumes.
- The legacy GKE `network_policy` add-on is a different feature path. The
  Terraform root intentionally leaves that off when Dataplane V2 is enabled.

### EKS

The EKS root uses the upstream EKS module and its built-in add-on support for:

- VPC CNI with `enableNetworkPolicy`
- EBS CSI

The initial in-repo example intentionally stops there. `ingress-nginx` and
`cert-manager` still happen in a second phase.

Why the initial root stays narrower:

- it validates cleanly with the cluster module alone
- it keeps the first Terraform layer consistent with the foundation-first
  contract used on GKE and DOKS
- the current `aws-ia/eks-blueprints-addons` line still pins the Helm provider
  to `< 3.0`, which is a real compatibility boundary worth documenting rather
  than hiding

### DigitalOcean

The DOKS root intentionally does not manage Kubernetes resources. The
DigitalOcean provider documentation explicitly says cluster creation generally
should not happen in the same Terraform module where Kubernetes provider
resources are used.

That is why the DOKS example is a cluster-foundation root, not a full add-on
or `helm_release` root.

## Version Baseline

As of March 22, 2026, these examples are pinned to the following major lines:

- GKE module `~> 44.0`
- EKS module `~> 21.15`

These versions match the current upstream module lines at the time this slice
was added. Revisit them before expanding the Terraform coverage further.

## Not Yet Supported

### AKS Terraform root

AKS is intentionally deferred in this first pass.

Reason:

- the current Azure AKS module line requires Terraform `>= 1.9`
- this repo's current local validation toolchain is still on Terraform `1.5.7`
- the AKS ingress story is also in motion because Microsoft is steering users
  from the managed nginx path toward Gateway API

That combination makes an AKS Terraform root too easy to overstate right now.

### Provider-managed data services

These examples do not provision:

- RDS / Cloud SQL / Azure Database / DigitalOcean Managed Databases
- S3 / GCS bucket policy details
- Route53 / Cloud DNS / DigitalOcean DNS records

Those are real production needs, but they should be added as explicit follow-on
blueprints rather than quietly mixed into the initial cluster examples.
