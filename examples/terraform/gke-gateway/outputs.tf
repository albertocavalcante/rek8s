output "cluster_name" {
  description = "Name of the GKE cluster."
  value       = module.gke.name
}

output "cluster_endpoint" {
  description = "GKE API server endpoint."
  value       = module.gke.endpoint
}

output "matching_rek8s_profile" {
  description = "rek8s values file that matches this cluster."
  value       = "examples/cluster-profiles/gke.yaml"
}

output "get_credentials_command" {
  description = "Command to merge this cluster into local kubeconfig."
  value       = "gcloud container clusters get-credentials ${module.gke.name} --region ${var.region} --project ${var.project_id}"
}

output "gateway_manifest" {
  description = "Gateway manifest to apply before installing rek8s."
  value       = "examples/gateways/gke-external-gateway.yaml"
}
