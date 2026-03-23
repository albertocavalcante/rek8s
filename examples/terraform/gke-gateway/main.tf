provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  pods_range_name     = "${var.cluster_name}-pods"
  services_range_name = "${var.cluster_name}-services"
}

resource "google_compute_network" "rek8s" {
  name                    = "${var.cluster_name}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "rek8s" {
  name          = "${var.cluster_name}-${var.region}"
  ip_cidr_range = var.subnetwork_cidr
  region        = var.region
  network       = google_compute_network.rek8s.id

  secondary_ip_range {
    range_name    = local.pods_range_name
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = local.services_range_name
    ip_cidr_range = var.services_cidr
  }
}

module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google"
  version = "~> 44.0"

  project_id         = var.project_id
  name               = var.cluster_name
  region             = var.region
  zones              = var.zones
  kubernetes_version = var.kubernetes_version
  release_channel    = var.release_channel

  network           = google_compute_network.rek8s.name
  subnetwork        = google_compute_subnetwork.rek8s.name
  ip_range_pods     = local.pods_range_name
  ip_range_services = local.services_range_name

  datapath_provider   = "ADVANCED_DATAPATH"
  gateway_api_channel = "CHANNEL_STANDARD"
  gce_pd_csi_driver   = true

  # Dataplane V2 already provides the NetworkPolicy behavior that the
  # matching rek8s GKE profile expects; do not re-enable the legacy add-on.
  network_policy = false

  horizontal_pod_autoscaling = true
  http_load_balancing        = true
  deletion_protection        = var.deletion_protection

  node_pools = [
    {
      name               = "rek8s-main"
      machine_type       = var.node_machine_type
      node_locations     = join(",", var.zones)
      min_count          = var.node_min_count
      max_count          = var.node_max_count
      local_ssd_count    = 0
      spot               = false
      disk_size_gb       = var.node_disk_size_gb
      disk_type          = var.node_disk_type
      image_type         = "COS_CONTAINERD"
      auto_repair        = true
      auto_upgrade       = true
      initial_node_count = var.node_min_count
    }
  ]

  node_pools_labels = {
    all = {
      rek8s = "true"
    }

    rek8s-main = {
      "rek8s/node-pool" = "main"
    }
  }
}
