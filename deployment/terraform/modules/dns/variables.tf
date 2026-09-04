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
  description = "Google Cloud Project ID where resources are deployed"
}

variable "dns_project_id" {
  type        = string
  description = "Google Cloud Project ID hosting the Cloud DNS Zone (defaults to project_id)"
  default     = null
}

variable "dns_zone_name" {
  type        = string
  description = "Name of the Cloud DNS Managed Zone"
}

variable "domain_name" {
  type        = string
  description = "Fully qualified domain name for the A2A Service"
}

variable "enable_create_dns_zone" {
  type        = bool
  description = "Whether to create the Cloud DNS zone (true) or use an existing zone (false)"
  default     = false
}

variable "dns_resource_record_name" {
  type        = string
  description = "DNS challenge record name from Certificate Manager DNS authorization"
  default     = null
}

variable "dns_resource_record_type" {
  type        = string
  description = "DNS challenge record type (e.g. CNAME)"
  default     = "CNAME"
}

variable "dns_resource_record_data" {
  type        = string
  description = "DNS challenge record data target"
  default     = null
}

variable "alb_internal_ip" {
  type        = string
  description = "Internal IP address of the Regional Application Load Balancer to create A record for"
  default     = null
}
