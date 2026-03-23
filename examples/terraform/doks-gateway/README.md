# DOKS Gateway Blueprint

This Terraform root creates a DOKS cluster shaped for the
[`digitalocean.yaml`](../../cluster-profiles/digitalocean.yaml) `rek8s`
profile.

It provisions:

- a dedicated VPC
- a VPC-native DOKS cluster
- a high-availability control plane
- an autoscaling worker pool
- a conservative control-plane firewall allowlist

It intentionally stops there.

DigitalOcean documents that a `digitalocean_kubernetes_cluster` resource
generally should not be created in the same Terraform module where Kubernetes
provider resources are also used. That is why this example is a cluster
foundation only. Install `cert-manager`, create the Gateway, and install
`rek8s` in a second phase.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
doctl kubernetes cluster kubeconfig save <cluster-name>
kubectl apply -f ../../gateways/doks-cilium-gateway.yaml
helm install rek8s ../../../charts/rek8s \
  -f ../../cluster-profiles/digitalocean.yaml \
  --set global.domain=build.example.com
```

## Main DOKS Gotchas

- Keep the Kubernetes-provider phase separate from cluster creation.
- This root sets up a VPC-native cluster, but Gateway API support still depends
  on using a DOKS version that supports the managed Cilium Gateway path.
- `do-block-storage` is `ReadWriteOnce`, so every Buildfarm worker PVC remains
  node-local from Kubernetes' perspective.
