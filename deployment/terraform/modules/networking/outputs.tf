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

output "network_id" {
  value = google_compute_network.gke_network.id
}

output "network_name" {
  value = google_compute_network.gke_network.name
}

output "network_self_link" {
  value = google_compute_network.gke_network.self_link
}

output "gke_subnet_id" {
  value = google_compute_subnetwork.gke_subnet.id
}

output "gke_subnet_name" {
  value = google_compute_subnetwork.gke_subnet.name
}

output "proxy_subnet_id" {
  value = google_compute_subnetwork.proxy_subnet.id
}

output "egress_subnet_id" {
  value = google_compute_subnetwork.egress_subnet.id
}

output "egress_net_attachment_id" {
  value = google_compute_network_attachment.egress_net_attachment.id
}

output "psc_nat_subnet_id" {
  value = google_compute_subnetwork.psc_nat_subnet.id
}
