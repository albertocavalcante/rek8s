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
