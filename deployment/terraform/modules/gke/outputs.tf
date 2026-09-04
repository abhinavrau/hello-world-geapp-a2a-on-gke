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

output "cluster_name" {
  value = google_container_cluster.app.name
}

output "cluster_id" {
  value = google_container_cluster.app.id
}

output "cluster_endpoint" {
  value = google_container_cluster.app.endpoint
}

output "cluster_ca_certificate" {
  value = google_container_cluster.app.master_auth[0].cluster_ca_certificate
}

output "app_sa_email" {
  value = google_service_account.app_sa.email
}

output "docker_repo_id" {
  value = google_artifact_registry_repository.docker_repo.id
}
