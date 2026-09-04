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

variable "project_name" {
  type        = string
  description = "Project name used as a base for resource naming"
  default     = "hello-world-a2a"
}

variable "project_id" {
  type        = string
  description = "Google Cloud Project ID for resource deployment."
}

variable "region" {
  type        = string
  description = "Google Cloud region for resource deployment (GKE and Internal ALB)."
  default     = "us-central1"
}

variable "egress_gateway_region" {
  type        = string
  description = "Google Cloud region where the Gemini Enterprise Agent Gateway resides."
  default     = "us-central1"
}

variable "domain_name" {
  type        = string
  description = "Fully qualified domain name for the A2A service."
  default     = "hello-world-a2a.example.com"
}

variable "dns_zone_name" {
  type        = string
  description = "Cloud DNS managed zone name"
  default     = "my-cloud-dns-zone"
}

variable "dns_project_id" {
  type        = string
  description = "Project ID hosting the Cloud DNS Zone (if different from project_id)"
  default     = null
}

variable "enable_create_dns_zone" {
  type        = bool
  description = "Whether to create a new Cloud DNS zone or use an existing zone"
  default     = false
}

variable "enable_agent_gateway" {
  type        = bool
  description = "Whether to provision the Agent Gateway and Authz policies"
  default     = true
}

variable "enable_observability" {
  type        = bool
  description = "Whether to provision BigQuery telemetry datasets and logging sinks"
  default     = true
}

variable "enable_k8s_workload" {
  type        = bool
  description = "Whether to manage the Kubernetes Deployment & Service via Terraform"
  default     = true
}

variable "fail_open" {
  type        = bool
  description = "Whether the IAP authorization extension should fail open"
  default     = true
}

variable "iap_enforcement_mode" {
  type        = string
  description = "IAP authorization mode on Agent Gateway ('DRY_RUN' or null for enforce)"
  default     = "DRY_RUN"
}

variable "feedback_logs_filter" {
  type        = string
  description = "Log Sink filter for capturing feedback data"
  default     = "jsonPayload.log_type=\"feedback\" jsonPayload.service_name=\"hello-world-a2a\""
}

variable "app_sa_roles" {
  description = "List of roles to assign to the application service account"
  type        = list(string)
  default = [
    "roles/aiplatform.user",
    "roles/logging.logWriter",
    "roles/cloudtrace.agent",
    "roles/storage.admin",
    "roles/serviceusage.serviceUsageConsumer",
  ]
}
