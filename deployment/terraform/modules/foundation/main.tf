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

locals {
  services = [
    "aiplatform.googleapis.com",
    "cloudbuild.googleapis.com",
    "bigquery.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "serviceusage.googleapis.com",
    "logging.googleapis.com",
    "cloudtrace.googleapis.com",
    "telemetry.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "agentregistry.googleapis.com",
    "discoveryengine.googleapis.com",
    "networkservices.googleapis.com",
    "networksecurity.googleapis.com",
    "iap.googleapis.com",
    "certificatemanager.googleapis.com",
    "publicca.googleapis.com",
    "dns.googleapis.com",
  ]
}

data "google_project" "project" {
  project_id = var.project_id
}

resource "google_project_service" "services" {
  count              = length(local.services)
  project            = var.project_id
  service            = local.services[count.index]
  disable_on_destroy = false
}

resource "google_project_service_identity" "vertex_sa" {
  provider   = google-beta
  project    = var.project_id
  service    = "aiplatform.googleapis.com"
  depends_on = [google_project_service.services]
}

resource "google_project_iam_member" "default_compute_sa_cloudbuild_builder" {
  project    = var.project_id
  role       = "roles/cloudbuild.builds.builder"
  member     = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
  depends_on = [google_project_service.services]
}
