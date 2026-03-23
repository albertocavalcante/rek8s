variable "api_key" {
  description = "Magalu Cloud API key for the Terraform provider."
  type        = string
  sensitive   = true
}

variable "region" {
  description = "Magalu Cloud region for the cluster."
  type        = string
  default     = "br-se1"
}

variable "cluster_name" {
  description = "Name of the Magalu Cloud Kubernetes cluster."
  type        = string
  default     = "rek8s-magalu"
}

variable "cluster_description" {
  description = "Description attached to the Magalu Cloud cluster."
  type        = string
  default     = "rek8s foundation cluster for Magalu Cloud"
}

variable "kubernetes_version" {
  description = "Magalu Cloud Kubernetes version. Review current available versions before apply."
  type        = string
  default     = "v1.33.6"
}

variable "cluster_ipv4_cidr" {
  description = "Pod network range for the cluster."
  type        = string
  default     = "192.168.0.0/16"
}

variable "services_ipv4_cidr" {
  description = "Service network range for the cluster."
  type        = string
  default     = "10.96.0.0/12"
}

variable "control_plane_allowed_cidrs" {
  description = "IPv4 CIDRs allowed to reach the Kubernetes API server."
  type        = list(string)
  default     = []
}

variable "nodepool_name" {
  description = "Name of the main Magalu Cloud node pool."
  type        = string
  default     = "rek8s-main"
}

variable "nodepool_flavor_name" {
  description = "Node pool flavor name. Verify it exists in the current region before apply."
  type        = string
  default     = "cloud-k8s.gp1.small"
}

variable "nodepool_replicas" {
  description = "Desired node count for the main node pool."
  type        = number
  default     = 3
}

variable "nodepool_min_replicas" {
  description = "Minimum node count for autoscaling."
  type        = number
  default     = 3
}

variable "nodepool_max_replicas" {
  description = "Maximum node count for autoscaling."
  type        = number
  default     = 6
}

variable "availability_zones" {
  description = "Availability zones used by the main node pool."
  type        = list(string)
  default     = ["a", "b", "c"]
}

variable "max_pods_per_node" {
  description = "Maximum pods scheduled on each worker node."
  type        = number
  default     = 110
}
