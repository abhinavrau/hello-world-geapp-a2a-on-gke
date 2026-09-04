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

variable "project_id" {
  type        = string
  description = "Google Cloud Project ID"
}

variable "project_name" {
  type        = string
  description = "Base name for resource naming"
  default     = "hello-world-a2a"
}

variable "region" {
  type        = string
  description = "Google Cloud region for GKE and Internal ALB"
  default     = "us-central1"
}

variable "egress_gateway_region" {
  type        = string
  description = "Google Cloud region where Agent Gateway and Egress Subnet reside"
  default     = "us-central1"
}

variable "gke_subnet_cidr" {
  type        = string
  description = "CIDR range for GKE subnet"
  default     = "10.0.0.0/20"
}

variable "proxy_subnet_cidr" {
  type        = string
  description = "CIDR range for Regional Managed Proxy-Only subnet"
  default     = "10.200.0.0/24"
}

variable "egress_subnet_cidr" {
  type        = string
  description = "CIDR range for Agent Gateway Egress subnet"
  default     = "10.10.0.0/20"
}

variable "psc_nat_subnet_cidr" {
  type        = string
  description = "CIDR range for PSC NAT subnet"
  default     = "10.100.0.0/24"
}

variable "connection_preference" {
  type        = string
  description = "Connection preference for the PSC Network Attachment (ACCEPT_AUTOMATIC or ACCEPT_MANUAL)"
  default     = "ACCEPT_AUTOMATIC"
}

variable "producer_accept_list" {
  type        = list(string)
  description = "List of consumer project IDs or numbers allowed to connect when connection_preference is ACCEPT_MANUAL"
  default     = []
}
