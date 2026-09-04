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

output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "project_number" {
  description = "GCP Project Number"
  value       = module.foundation.project_number
}

output "network_name" {
  description = "VPC Network Name"
  value       = module.networking.network_name
}

output "gke_cluster_name" {
  description = "GKE Cluster Name"
  value       = module.gke.cluster_name
}

output "alb_internal_ip" {
  description = "Regional Internal Application Load Balancer VIP"
  value       = module.internal_lb.internal_ip
}

output "domain_name" {
  description = "Fully Qualified Domain Name for A2A Service"
  value       = var.domain_name
}

output "certificate_id" {
  description = "Certificate Manager Regional Certificate ID"
  value       = module.certificates.certificate_id
}

output "agent_gateway_id" {
  description = "Agent Gateway Resource ID"
  value       = var.enable_agent_gateway ? module.agent_gateway[0].agent_gateway_id : null
}
