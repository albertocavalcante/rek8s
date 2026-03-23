provider "mgc" {
  api_key = var.api_key
  region  = var.region
}

data "mgc_kubernetes_version" "available" {
  include_deprecated = false
}

data "mgc_kubernetes_flavor" "available" {}

locals {
  available_kubernetes_versions = [
    for item in data.mgc_kubernetes_version.available.versions : item.version
  ]

  available_nodepool_flavors = [
    for item in data.mgc_kubernetes_flavor.available.nodepool : item.name
  ]
}

resource "mgc_kubernetes_cluster" "rek8s" {
  name               = var.cluster_name
  version            = var.kubernetes_version
  description        = var.cluster_description
  cluster_ipv4_cidr  = var.cluster_ipv4_cidr
  services_ipv4_cidr = var.services_ipv4_cidr
  allowed_cidrs      = var.control_plane_allowed_cidrs

  lifecycle {
    precondition {
      condition     = contains(local.available_kubernetes_versions, var.kubernetes_version)
      error_message = "kubernetes_version is not in the current non-deprecated Magalu Cloud version list. Review the available_kubernetes_versions output."
    }
  }
}

resource "mgc_kubernetes_nodepool" "rek8s_main" {
  cluster_id         = mgc_kubernetes_cluster.rek8s.id
  name               = var.nodepool_name
  flavor_name        = var.nodepool_flavor_name
  replicas           = var.nodepool_replicas
  min_replicas       = var.nodepool_min_replicas
  max_replicas       = var.nodepool_max_replicas
  availability_zones = var.availability_zones
  max_pods_per_node  = var.max_pods_per_node

  lifecycle {
    precondition {
      condition     = contains(local.available_nodepool_flavors, var.nodepool_flavor_name)
      error_message = "nodepool_flavor_name is not in the current Magalu Cloud nodepool flavor list. Review the available_nodepool_flavors output."
    }
    precondition {
      condition     = var.nodepool_min_replicas <= var.nodepool_replicas && var.nodepool_replicas <= var.nodepool_max_replicas
      error_message = "nodepool_replicas must be between nodepool_min_replicas and nodepool_max_replicas."
    }
  }
}
