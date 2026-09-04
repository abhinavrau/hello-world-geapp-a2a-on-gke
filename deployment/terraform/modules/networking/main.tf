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

# VPC Network
resource "google_compute_network" "gke_network" {
  name                    = "${var.project_name}-network"
  project                 = var.project_id
  auto_create_subnetworks = false
}

# Subnet for GKE cluster
resource "google_compute_subnetwork" "gke_subnet" {
  name          = "${var.project_name}-subnet"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.gke_network.id
  ip_cidr_range = var.gke_subnet_cidr
}

# Regional Proxy-Only Subnet for Internal Application Load Balancer
resource "google_compute_subnetwork" "proxy_subnet" {
  name          = "${var.project_name}-proxy-subnet"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.gke_network.id
  ip_cidr_range = var.proxy_subnet_cidr
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

# Subnet in Agent Gateway Region for Egress Network Attachment
resource "google_compute_subnetwork" "egress_subnet" {
  name          = "${var.project_name}-subnet-egress"
  project       = var.project_id
  region        = var.egress_gateway_region
  network       = google_compute_network.gke_network.id
  ip_cidr_range = var.egress_subnet_cidr
}

# PSC Network Attachment for Egress Gateway
resource "google_compute_network_attachment" "egress_net_attachment" {
  name                  = "${var.project_name}-net-attachment-egress"
  project               = var.project_id
  region                = var.egress_gateway_region
  connection_preference = var.connection_preference
  producer_accept_lists = length(var.producer_accept_list) > 0 ? var.producer_accept_list : null
  subnetworks           = [google_compute_subnetwork.egress_subnet.id]
}

# PSC NAT Subnet for Private Service Connect Service Attachment
resource "google_compute_subnetwork" "psc_nat_subnet" {
  name          = "${var.project_name}-psc-nat-subnet"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.gke_network.id
  ip_cidr_range = var.psc_nat_subnet_cidr
  purpose       = "PRIVATE_SERVICE_CONNECT"
}

# Cloud Router for NAT gateway
resource "google_compute_router" "router" {
  name    = "${var.project_name}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.gke_network.id
}

# Cloud NAT for private GKE nodes to access the internet
resource "google_compute_router_nat" "nat" {
  name                               = "${var.project_name}-nat"
  project                            = var.project_id
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# Firewall rule to allow internal traffic
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.project_name}-allow-internal"
  network = google_compute_network.gke_network.name
  project = var.project_id

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/8"]
}

# Firewall rule to allow proxy-only subnet to reach GKE pods on port 8080
resource "google_compute_firewall" "allow_proxy" {
  name    = "${var.project_name}-allow-proxy"
  network = google_compute_network.gke_network.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = [google_compute_subnetwork.proxy_subnet.ip_cidr_range]
}

# Firewall rule to allow egress gateway from gateway region to reach internal endpoints
resource "google_compute_firewall" "allow_egress_gateway" {
  name    = "${var.project_name}-allow-egress-gateway"
  network = google_compute_network.gke_network.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["8080", "443", "80"]
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = [google_compute_subnetwork.egress_subnet.ip_cidr_range]
}

# Firewall rule to allow health checks and traffic from PSC NAT subnet
resource "google_compute_firewall" "allow_psc_nat" {
  name    = "${var.project_name}-allow-psc-nat"
  network = google_compute_network.gke_network.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = [
    google_compute_subnetwork.psc_nat_subnet.ip_cidr_range,
    "35.191.0.0/16",
    "130.211.0.0/22"
  ]
}
