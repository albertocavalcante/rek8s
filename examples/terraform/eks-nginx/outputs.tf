output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "matching_rek8s_profile" {
  description = "rek8s values file that matches this cluster."
  value       = "examples/cluster-profiles/eks.yaml"
}

output "update_kubeconfig_command" {
  description = "Command to merge this cluster into local kubeconfig."
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
}

output "ingress_class_name" {
  description = "Ingress class expected by the matching rek8s profile."
  value       = "nginx"
}
