provider "digitalocean" {}

data "digitalocean_kubernetes_versions" "this" {
  version_prefix = var.version_prefix
}

resource "digitalocean_vpc" "rek8s" {
  name     = "${var.cluster_name}-vpc"
  region   = var.region
  ip_range = var.vpc_ip_range
}

resource "digitalocean_kubernetes_cluster" "rek8s" {
  name    = var.cluster_name
  region  = var.region
  version = data.digitalocean_kubernetes_versions.this.latest_version

  vpc_uuid       = digitalocean_vpc.rek8s.id
  cluster_subnet = var.cluster_subnet
  service_subnet = var.service_subnet

  ha            = true
  auto_upgrade  = true
  surge_upgrade = true

  control_plane_firewall {
    enabled           = true
    allowed_addresses = var.control_plane_allowed_cidrs
  }

  maintenance_policy {
    day        = "sunday"
    start_time = "04:00"
  }

  node_pool {
    name       = "rek8s-main"
    size       = var.node_size
    auto_scale = true
    min_nodes  = var.min_nodes
    max_nodes  = var.max_nodes
    tags       = ["rek8s"]
    labels = {
      rek8s = "true"
    }
  }
}
