variable "region" {
  description = "AWS region for the EKS cluster."
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
  default     = "rek8s-eks"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes minor version."
  type        = string
  default     = "1.33"
}

variable "vpc_cidr" {
  description = "CIDR block for the EKS VPC."
  type        = string
  default     = "10.60.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones to use for the EKS VPC and node group."
  type        = list(string)
  default     = []
}

variable "node_instance_types" {
  description = "Instance types for the main EKS managed node group."
  type        = list(string)
  default     = ["m6i.xlarge"]
}

variable "node_min_size" {
  description = "Minimum size for the managed node group."
  type        = number
  default     = 3
}

variable "node_max_size" {
  description = "Maximum size for the managed node group."
  type        = number
  default     = 6
}

variable "node_desired_size" {
  description = "Desired size for the managed node group."
  type        = number
  default     = 3
}

variable "tags" {
  description = "Tags applied to created AWS resources."
  type        = map(string)
  default = {
    Terraform = "true"
    Workload  = "rek8s"
  }
}
