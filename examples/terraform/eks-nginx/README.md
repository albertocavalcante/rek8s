# EKS nginx Blueprint

This Terraform root creates an EKS cluster shaped for the
[`eks.yaml`](../../cluster-profiles/eks.yaml) `rek8s` profile.

It provisions:

- a dedicated VPC with public and private subnets
- an EKS control plane and managed node group
- the Amazon VPC CNI add-on with Kubernetes network policy enabled
- the EBS CSI add-on

This example uses the `terraform-aws-modules/eks/aws` module for the cluster
and its AWS-managed add-on support for the core EKS pieces that `rek8s` needs.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
aws eks update-kubeconfig --name <cluster-name> --region <region>
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true
helm install rek8s ../../../charts/rek8s \
  -f ../../cluster-profiles/eks.yaml \
  --set global.domain=build.example.com
```

## Main EKS Gotchas

- The `rek8s` EKS profile relies on standard Kubernetes `NetworkPolicy`, which
  on EKS means the VPC CNI network-policy feature must actually be enabled.
- This root intentionally stops at cluster foundation plus AWS-managed add-ons.
  Install `ingress-nginx` and `cert-manager` in a second phase.
- Keep AWS load-balancer annotations on the ingress controller service, not on
  the application Ingress resources rendered by `rek8s`.
- This root does not create Route53 zones, ACM certificates, RDS, or S3
  buckets for you.
