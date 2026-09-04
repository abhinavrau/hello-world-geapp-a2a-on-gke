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
  actual_dns_project_id = coalesce(var.dns_project_id, var.project_id)
  domain_name_dot       = "${trimsuffix(var.domain_name, ".")}."
}

# Lookup existing Cloud DNS Managed Zone
data "google_dns_managed_zone" "existing" {
  count   = var.enable_create_dns_zone ? 0 : 1
  name    = var.dns_zone_name
  project = local.actual_dns_project_id
}

# Optional: Create Cloud DNS Managed Zone if requested
resource "google_dns_managed_zone" "managed_zone" {
  count       = var.enable_create_dns_zone ? 1 : 0
  name        = var.dns_zone_name
  project     = local.actual_dns_project_id
  dns_name    = local.domain_name_dot
  description = "Managed Zone for A2A Service"
}

locals {
  zone_name = var.enable_create_dns_zone ? google_dns_managed_zone.managed_zone[0].name : data.google_dns_managed_zone.existing[0].name
}

# Certificate Manager DNS Authorization Challenge Record
resource "google_dns_record_set" "cert_dns_auth" {
  project      = local.actual_dns_project_id
  managed_zone = local.zone_name
  name         = var.dns_resource_record_name
  type         = var.dns_resource_record_type
  ttl          = 60
  rrdatas      = [var.dns_resource_record_data]
}

# A Record pointing DOMAIN_NAME to ALB_INTERNAL_IP
resource "google_dns_record_set" "alb_a_record" {
  project      = local.actual_dns_project_id
  managed_zone = local.zone_name
  name         = local.domain_name_dot
  type         = "A"
  ttl          = 300
  rrdatas      = [var.alb_internal_ip]
}
