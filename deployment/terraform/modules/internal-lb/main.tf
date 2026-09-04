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

# Discover available zones in the region dynamically
data "google_compute_zones" "available" {
  region  = var.region
  project = var.project_id
}

locals {
  neg_zones = var.neg_zones != null ? var.neg_zones : data.google_compute_zones.available.names
}

# Regional Health Check for Internal ALB
resource "google_compute_region_health_check" "alb_health_check" {
  name               = "${var.project_name}-alb-hc"
  project            = var.project_id
  region             = var.region
  check_interval_sec = 10
  timeout_sec        = 5

  http_health_check {
    port         = 8080
    request_path = "/docs"
  }
}

# Allocate static internal IP for ALB if requested and not provided explicitly
resource "google_compute_address" "alb_ip" {
  count        = var.create_address && var.internal_ip_address == null ? 1 : 0
  name         = "${var.project_name}-alb-ip"
  project      = var.project_id
  region       = var.region
  subnetwork   = var.subnetwork_id
  address_type = "INTERNAL"
  description  = "Internal IP for Regional Application Load Balancer"
}

locals {
  effective_ip = coalesce(
    var.internal_ip_address,
    length(google_compute_address.alb_ip) > 0 ? google_compute_address.alb_ip[0].address : null
  )
}

# Regional Backend Service pointing to GKE Standalone NEGs
resource "google_compute_region_backend_service" "alb_backend_service" {
  name                  = "${var.project_name}-backend-service"
  project               = var.project_id
  region                = var.region
  protocol              = "HTTP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  health_checks         = [google_compute_region_health_check.alb_health_check.id]

  dynamic "backend" {
    for_each = local.neg_zones
    content {
      group                 = "https://www.googleapis.com/compute/v1/projects/${var.project_id}/zones/${backend.value}/networkEndpointGroups/${var.neg_name}"
      balancing_mode        = "RATE"
      max_rate_per_endpoint = 100
      capacity_scaler       = 1.0
    }
  }

  depends_on = [
    var.proxy_subnet_id
  ]
}

# Regional URL Map
resource "google_compute_region_url_map" "alb_url_map" {
  name            = "${var.project_name}-url-map"
  project         = var.project_id
  region          = var.region
  default_service = google_compute_region_backend_service.alb_backend_service.id
}

# Target HTTPS Proxy using Certificate Manager regional certificate
resource "google_compute_region_target_https_proxy" "alb_https_proxy" {
  name                             = "${var.project_name}-https-proxy"
  project                          = var.project_id
  region                           = var.region
  url_map                          = google_compute_region_url_map.alb_url_map.id
  certificate_manager_certificates = [var.certificate_id]
}

# Regional Internal Forwarding Rule with Global Access
resource "google_compute_forwarding_rule" "alb_forwarding_rule" {
  name                  = "${var.project_name}-alb-fr"
  project               = var.project_id
  region                = var.region
  load_balancing_scheme = "INTERNAL_MANAGED"
  network               = var.network_id
  subnetwork            = var.subnetwork_id
  ip_address            = local.effective_ip
  ip_protocol           = "TCP"
  port_range            = "443"
  target                = google_compute_region_target_https_proxy.alb_https_proxy.id
  allow_global_access   = true
}
