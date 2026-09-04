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

output "certificate_id" {
  description = "The ID of the regional Certificate Manager certificate"
  value       = google_certificate_manager_certificate.regional.id
}

output "certificate_name" {
  description = "The name of the regional Certificate Manager certificate"
  value       = google_certificate_manager_certificate.regional.name
}

output "dns_authorization_id" {
  description = "The ID of the DNS authorization resource"
  value       = google_certificate_manager_dns_authorization.dns_auth.id
}

output "dns_resource_record_name" {
  description = "The DNS challenge record name"
  value       = google_certificate_manager_dns_authorization.dns_auth.dns_resource_record[0].name
}

output "dns_resource_record_type" {
  description = "The DNS challenge record type"
  value       = google_certificate_manager_dns_authorization.dns_auth.dns_resource_record[0].type
}

output "dns_resource_record_data" {
  description = "The DNS challenge record data"
  value       = google_certificate_manager_dns_authorization.dns_auth.dns_resource_record[0].data
}
