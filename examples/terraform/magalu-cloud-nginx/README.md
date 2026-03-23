# Magalu Cloud nginx Blueprint

This Terraform root creates a Magalu Cloud Kubernetes cluster shaped for the
[`magalu-cloud.yaml`](../../cluster-profiles/magalu-cloud.yaml) `rek8s`
profile.

It provisions:

- a managed Magalu Cloud Kubernetes cluster
- a main autoscaling node pool
- explicit pod and service CIDRs
- optional API server CIDR restrictions

It intentionally stops at cluster foundation. `ingress-nginx`,
`cert-manager`, and `rek8s` remain a second phase.

## Verification Status

This example was re-checked against Magalu primary sources on March 22, 2026.

Validated locally in this repo:

- `terraform validate` for this Terraform root
- full `./tools/scripts/validate-terraform.sh` across all Terraform examples
- `helm lint ./charts/rek8s`
- `helm template` with [`../../cluster-profiles/magalu-cloud.yaml`](../../cluster-profiles/magalu-cloud.yaml)
- YAML parsing of [`../../ingress-nginx/magalu-cloud-public.yaml`](../../ingress-nginx/magalu-cloud-public.yaml)

Not validated here:

- a live `terraform apply` against a real Magalu account
- a live `helm install` on an actual Magalu cluster

That means the foundation shape, provider resources, current version defaults,
and install flow are source-backed and locally validated, but final
environment-specific behavior still depends on your Magalu credentials,
selected region, and currently available flavors.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
mgc kubernetes cluster kubeconfig --cluster-id "$(terraform output -raw cluster_id)" --raw > rek8s-magalu.kubeconfig
export KUBECONFIG="$PWD/rek8s-magalu.kubeconfig"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  -f ../../ingress-nginx/magalu-cloud-public.yaml
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true
helm install rek8s ../../../charts/rek8s \
  -f ../../cluster-profiles/magalu-cloud.yaml \
  --set global.domain=build.example.com
```

## Main Magalu Cloud Gotchas

- Target Magalu platform `v3`. As of March 22, 2026, Magalu documents `v1` as
  obsolete for new clusters and `v3` as the default multi-AZ platform.
- Magalu `v3` uses Calico as the cluster CNI. `rek8s` stays on standard
  Kubernetes `NetworkPolicy` for this path.
- The default `mgc-csi-magalu-sc` storage class uses `Retain` and
  `WaitForFirstConsumer`, so deleting a PVC does not delete the backing volume
  and volumes are created only when a pod is scheduled.
- If you restrict the ingress controller with
  `controller.service.loadBalancerSourceRanges`, Magalu requires you to include
  the cluster CIDR in that allowlist.
- Magalu documents that service load balancers and block volumes must be
  deleted manually if you remove the cluster before cleaning those resources
  up.
- Magalu kubeconfig certificates expire after one year. Download a new
  kubeconfig before the old one expires.
- The provider documents `enabled_server_group` as a write-only field that
  needs Terraform `1.11+`, so this root leaves it unset to stay compatible
  with the repo's current Terraform `1.5.x` baseline.

## Current Defaults In This Example

- `region = "br-se1"`
- `kubernetes_version = "v1.33.6"`
- `nodepool_flavor_name = "cloud-k8s.gp1.small"`
- `availability_zones = ["a", "b", "c"]`
- `storageClass = "mgc-csi-magalu-sc"` in the matching `rek8s` profile

Reasoning:

- `v1.33.6` is still in Magalu's currently available Kubernetes version list
  as of March 22, 2026.
- `cloud-k8s.gp1.small` appears in Magalu's official Terraform example repo.
- The Terraform root also checks the requested Kubernetes version and nodepool
  flavor against the provider's live data sources before apply.

## References

- Magalu Kubernetes quick start:
  <https://docs.magalu.cloud/docs/containers-manager/kubernetes/getting-started/>
- Magalu platform versions:
  <https://docs.magalu.cloud/docs/containers-manager/kubernetes/additional-explanations/versions/>
- Magalu currently available Kubernetes versions:
  <https://docs.magalu.cloud/docs/containers-manager/kubernetes/additional-explanations/kubernetes-versions/>
- Magalu service load balancer configuration:
  <https://docs.magalu.cloud/docs/containers-manager/kubernetes/how-to/load-balancers/service/conf-service-lb/>
- Magalu storage class details:
  <https://docs.magalu.cloud/docs/containers-manager/kubernetes/how-to/persistent-volumes/storage-class/>
- Magalu Terraform provider:
  <https://registry.terraform.io/providers/magalucloud/mgc/latest>
- Magalu Terraform provider docs source:
  <https://github.com/MagaluCloud/terraform-provider-mgc>
- Magalu Terraform examples:
  <https://github.com/MagaluCloud/terraform-examples>
