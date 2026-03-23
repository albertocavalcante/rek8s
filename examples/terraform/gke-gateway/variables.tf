variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "GCP region for the GKE cluster."
  type        = string
}

variable "zones" {
  description = "GCP zones for the GKE node pool."
  type        = list(string)
}

variable "cluster_name" {
  description = "Name of the GKE cluster."
  type        = string
  default     = "rek8s-gke"
}

variable "subnetwork_cidr" {
  description = "Primary subnet CIDR for the GKE VPC subnet."
  type        = string
  default     = "10.40.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary subnet CIDR for pod IPs."
  type        = string
  default     = "10.44.0.0/16"
}

variable "services_cidr" {
  description = "Secondary subnet CIDR for service IPs."
  type        = string
  default     = "10.48.0.0/20"
}

variable "kubernetes_version" {
  description = "GKE Kubernetes version or release alias."
  type        = string
  default     = "latest"
}

variable "release_channel" {
  description = "GKE release channel."
  type        = string
  default     = "REGULAR"
}

variable "node_machine_type" {
  description = "Machine type for the main rek8s worker pool."
  type        = string
  default     = "e2-standard-4"
}

variable "node_min_count" {
  description = "Minimum node count for the main node pool."
  type        = number
  default     = 3
}

variable "node_max_count" {
  description = "Maximum node count for the main node pool."
  type        = number
  default     = 6
}

variable "node_disk_size_gb" {
  description = "Boot disk size in GiB for worker nodes."
  type        = number
  default     = 200
}

variable "node_disk_type" {
  description = "Boot disk type for worker nodes."
  type        = string
  default     = "pd-ssd"
}

variable "deletion_protection" {
  description = "Prevent accidental cluster deletion."
  type        = bool
  default     = true
}
