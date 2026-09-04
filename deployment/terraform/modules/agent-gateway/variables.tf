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

variable "project_number" {
  type        = string
  description = "Google Cloud Project Number"
}

variable "gateway_name" {
  type        = string
  description = "Name of the Agent Gateway"
  default     = "hello-world-a2a-egress-gateway"
}

variable "gateway_region" {
  type        = string
  description = "Google Cloud region where Agent Gateway resides"
  default     = "us-central1"
}

variable "network_self_link" {
  type        = string
  description = "Customer VPC network self link (optional when dns_peering_domains is empty)"
  default     = ""
}

variable "registry_project_id" {
  type        = string
  description = "Google Cloud Project ID hosting the Agent Registry (defaults to project_id)"
  default     = null
}

variable "egress_net_attachment_id" {
  type        = string
  description = "PSC network attachment ID in the gateway region"
}

variable "dns_peering_domains" {
  type        = list(string)
  description = "List of domain names to peer with customer VPC"
  default     = []
}

variable "iap_enforcement_mode" {
  type        = string
  description = "IAP authorization enforcement mode (DRY_RUN or null for ENFORCE)"
  default     = "DRY_RUN"
}

variable "fail_open" {
  type        = bool
  description = "Whether the IAP authorization extension should fail open"
  default     = true
}

variable "authz_extension_timeout" {
  type        = string
  description = "Timeout for authz extension callouts"
  default     = "10s"
}
