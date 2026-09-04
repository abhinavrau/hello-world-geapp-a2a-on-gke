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
  description = "Google Cloud region for the Regional Internal ALB"
  default     = "us-central1"
}

variable "network_id" {
  type        = string
  description = "VPC Network ID"
}

variable "subnetwork_id" {
  type        = string
  description = "Subnet ID where the ALB Forwarding Rule VIP resides"
}

variable "proxy_subnet_id" {
  type        = string
  description = "Regional Proxy-Only Subnet ID"
}

variable "neg_name" {
  type        = string
  description = "GKE Standalone NEG name"
}

variable "neg_zones" {
  type        = list(string)
  description = "List of zones where Standalone NEG is deployed (defaults to first available zone)"
  default     = null
}

variable "certificate_id" {
  type        = string
  description = "Certificate Manager regional certificate ID"
}

variable "internal_ip_address" {
  type        = string
  description = "Explicit internal IP address for the ALB. If null, a static internal IP is allocated."
  default     = null
}

variable "create_address" {
  type        = bool
  description = "Whether to allocate a static internal IP address"
  default     = true
}
