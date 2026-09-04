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

output "internal_ip" {
  description = "The internal VIP of the Application Load Balancer"
  value       = local.effective_ip
}

output "forwarding_rule_id" {
  value = google_compute_forwarding_rule.alb_forwarding_rule.id
}

output "backend_service_id" {
  value = google_compute_region_backend_service.alb_backend_service.id
}

output "url_map_id" {
  value = google_compute_region_url_map.alb_url_map.id
}

output "https_proxy_id" {
  value = google_compute_region_target_https_proxy.alb_https_proxy.id
}
