# Terraform Examples

These examples provision cluster foundations that match existing `rek8s`
cluster profiles.

They are intentionally opinionated, but they are not trying to be a complete
platform factory. The default operating model is:

1. use Terraform to create the cluster and provider-shaped prerequisites
2. fetch kubeconfig
3. install `rek8s` with the matching Helm profile from
   [`examples/cluster-profiles/`](../cluster-profiles/)

## Available Blueprints

| Blueprint | Path | Matching profile | Notes |
|-----------|------|------------------|-------|
| GKE Gateway | [`gke-gateway`](./gke-gateway/) | [`../cluster-profiles/gke.yaml`](../cluster-profiles/gke.yaml) | Dataplane V2 + Gateway API |
| EKS nginx | [`eks-nginx`](./eks-nginx/) | [`../cluster-profiles/eks.yaml`](../cluster-profiles/eks.yaml) | Uses the EKS module plus AWS-managed core add-ons |
| DOKS Gateway | [`doks-gateway`](./doks-gateway/) | [`../cluster-profiles/digitalocean.yaml`](../cluster-profiles/digitalocean.yaml) | Cluster foundation only by design |

## Shared Rules

- Review every default before applying in production.
- These roots do not provision your application database or object storage.
- Gateway API profiles still require a concrete `Gateway` object after cluster
  bring-up.
- The Helm chart install remains a separate step unless a provider path has a
  very mature in-module add-on story.

For the design rationale and provider-specific tradeoffs, see
[`docs/terraform-blueprints.md`](../../docs/terraform-blueprints.md).
