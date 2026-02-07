# -----------------------------------------------------------------------------
# GKE Cluster
# -----------------------------------------------------------------------------

resource "google_container_cluster" "superplane" {
  name     = var.cluster_name
  location = var.zone

  initial_node_count       = var.node_count
  remove_default_node_pool = false

  min_master_version = var.cluster_version
  release_channel {
    channel = "REGULAR"
  }

  network = var.network

  # Enable Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Private cluster config for security
  private_cluster_config {
    enable_private_nodes    = false
    enable_private_endpoint = false
  }

  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  node_config {
    machine_type = var.machine_type

    oauth_scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  depends_on = [
    google_project_service.container
  ]
}
