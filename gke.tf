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

  node_config {
    machine_type = var.machine_type

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  depends_on = [
    google_project_service.container
  ]
}
