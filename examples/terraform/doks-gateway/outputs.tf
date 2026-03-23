output "cluster_name" {
  description = "Name of the DOKS cluster."
  value       = digitalocean_kubernetes_cluster.rek8s.name
}

output "cluster_id" {
  description = "DigitalOcean Kubernetes cluster ID."
  value       = digitalocean_kubernetes_cluster.rek8s.id
}

output "matching_rek8s_profile" {
  description = "rek8s values file that matches this cluster."
  value       = "examples/cluster-profiles/digitalocean.yaml"
}

output "kubeconfig_command" {
  description = "Command to save kubeconfig for this cluster."
  value       = "doctl kubernetes cluster kubeconfig save ${digitalocean_kubernetes_cluster.rek8s.name}"
}

output "gateway_manifest" {
  description = "Gateway manifest to apply before installing rek8s."
  value       = "examples/gateways/doks-cilium-gateway.yaml"
}
