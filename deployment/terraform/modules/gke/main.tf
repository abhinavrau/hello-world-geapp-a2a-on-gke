# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# GKE Autopilot Cluster
resource "google_container_cluster" "app" {
  name     = var.project_name
  location = var.region
  project  = var.project_id

  network    = var.network_name
  subnetwork = var.subnetwork_name

  enable_autopilot = true
  node_locations   = var.node_locations

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
  }

  ip_allocation_policy {}

  deletion_protection = false
}

# Artifact Registry for container images
resource "google_artifact_registry_repository" "docker_repo" {
  location      = var.region
  repository_id = var.project_name
  format        = "DOCKER"
  project       = var.project_id
}

# Application Service Account
resource "google_service_account" "app_sa" {
  account_id   = "${var.project_name}-app"
  display_name = "${var.project_name} Agent Service Account"
  project      = var.project_id
}

# Grant IAM roles to application SA
resource "google_project_iam_member" "app_sa_roles" {
  for_each = toset(var.app_sa_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.app_sa.email}"
}

# Allow GKE KSA to impersonate GCP SA via Workload Identity
resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = google_service_account.app_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.project_name}/${var.project_name}]"

  depends_on = [google_container_cluster.app]
}
