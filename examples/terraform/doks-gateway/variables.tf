variable "region" {
  description = "DigitalOcean region slug for the cluster."
  type        = string
}

variable "cluster_name" {
  description = "Name of the DOKS cluster."
  type        = string
  default     = "rek8s-doks"
}

variable "version_prefix" {
  description = "Kubernetes version prefix to select for DOKS."
  type        = string
  default     = "1.33."
}

variable "vpc_ip_range" {
  description = "CIDR for the dedicated DOKS VPC."
  type        = string
  default     = "10.70.0.0/16"
}

variable "cluster_subnet" {
  description = "Pod network range for the VPC-native cluster."
  type        = string
  default     = "10.80.0.0/16"
}

variable "service_subnet" {
  description = "Service network range for the VPC-native cluster."
  type        = string
  default     = "10.81.0.0/20"
}

variable "node_size" {
  description = "Worker node size slug."
  type        = string
  default     = "s-4vcpu-8gb"
}

variable "min_nodes" {
  description = "Minimum worker nodes in the default pool."
  type        = number
  default     = 3
}

variable "max_nodes" {
  description = "Maximum worker nodes in the default pool."
  type        = number
  default     = 6
}

variable "control_plane_allowed_cidrs" {
  description = "CIDRs allowed to reach the DOKS control plane."
  type        = list(string)
}
