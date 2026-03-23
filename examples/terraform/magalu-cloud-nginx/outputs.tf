output "cluster_id" {
  description = "Magalu Cloud Kubernetes cluster ID."
  value       = mgc_kubernetes_cluster.rek8s.id
}

output "cluster_name" {
  description = "Name of the Magalu Cloud Kubernetes cluster."
  value       = mgc_kubernetes_cluster.rek8s.name
}

output "platform_version" {
  description = "Magalu Cloud Kubernetes platform version reported after creation."
  value       = mgc_kubernetes_cluster.rek8s.platform_version
}

output "matching_rek8s_profile" {
  description = "rek8s values file that matches this cluster."
  value       = "examples/cluster-profiles/magalu-cloud.yaml"
}

output "ingress_nginx_values_file" {
  description = "ingress-nginx values file shaped for Magalu Cloud service load balancers."
  value       = "examples/ingress-nginx/magalu-cloud-public.yaml"
}

output "kubeconfig_command" {
  description = "Command to save kubeconfig for this cluster."
  value       = "mgc kubernetes cluster kubeconfig --cluster-id ${mgc_kubernetes_cluster.rek8s.id} --raw > ${var.cluster_name}.kubeconfig"
}

output "available_kubernetes_versions" {
  description = "Current non-deprecated Magalu Cloud Kubernetes versions returned by the provider."
  value       = local.available_kubernetes_versions
}

output "available_nodepool_flavors" {
  description = "Current Magalu Cloud nodepool flavors returned by the provider."
  value       = local.available_nodepool_flavors
}
