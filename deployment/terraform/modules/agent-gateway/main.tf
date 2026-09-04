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
  registry_project = coalesce(var.registry_project_id, var.project_id)
  registry_uri     = "//agentregistry.googleapis.com/projects/${local.registry_project}/locations/global"
}

# --- Service Agent IAM Permissions ---

# Custom role for Discovery Engine to access Agent Registry and Agent Gateway
resource "google_project_iam_custom_role" "agent_gateway_ge_access" {
  role_id     = "agent_gateway_ge_access"
  title       = "Agent Gateway GE Access"
  description = "Permissions required by Gemini Enterprise Discovery Engine to use Agent Gateway and Agent Registry"
  permissions = [
    "agentregistry.agents.get",
    "agentregistry.agents.list",
    "agentregistry.mcpServers.get",
    "agentregistry.mcpServers.list",
    "networkservices.agentGateways.get",
    "networkservices.agentGateways.list",
    "networkservices.agentGateways.use",
  ]
}

# Grant custom role and networkUser to Discovery Engine Service Agent
resource "google_project_iam_member" "discoveryengine_agent_gateway_access" {
  project = var.project_id
  role    = google_project_iam_custom_role.agent_gateway_ge_access.id
  member  = "serviceAccount:service-${var.project_number}@gcp-sa-discoveryengine.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "discoveryengine_network_user" {
  project = var.project_id
  role    = "roles/compute.networkUser"
  member  = "serviceAccount:service-${var.project_number}@gcp-sa-discoveryengine.iam.gserviceaccount.com"
}

# Grant networkUser and dns.peer to Agent Gateway Service Agent
resource "google_project_iam_member" "agent_gateway_network_user" {
  project = var.project_id
  role    = "roles/compute.networkUser"
  member  = "serviceAccount:service-${var.project_number}@gcp-sa-agentgateway.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "agent_gateway_dns_peer" {
  project = var.project_id
  role    = "roles/dns.peer"
  member  = "serviceAccount:service-${var.project_number}@gcp-sa-agentgateway.iam.gserviceaccount.com"
}

# --- Agent Gateway ---

resource "google_network_services_agent_gateway" "this" {
  provider = google-beta
  project  = var.project_id
  name     = var.gateway_name
  location = var.gateway_region

  google_managed {
    governed_access_path = "AGENT_TO_ANYWHERE"
  }

  registries = [local.registry_uri]

  network_config {
    egress {
      network_attachment = var.egress_net_attachment_id
    }

    dynamic "dns_peering_config" {
      for_each = length(var.dns_peering_domains) > 0 ? [1] : []
      content {
        domains        = [for d in var.dns_peering_domains : "${trimsuffix(d, ".")}."]
        target_project = var.project_id
        target_network = trimprefix(var.network_self_link, "https://www.googleapis.com/compute/v1/")
      }
    }
  }
}

# Stabilize before attaching policies
resource "time_sleep" "wait_for_gateway" {
  depends_on      = [google_network_services_agent_gateway.this]
  create_duration = "30s"
}

# IAP REQUEST_AUTHZ Service Extension
resource "google_network_services_authz_extension" "iap" {
  provider  = google-beta
  project   = var.project_id
  name      = "${var.gateway_name}-iap-authz"
  location  = var.gateway_region
  service   = "iap.googleapis.com"
  timeout   = var.authz_extension_timeout
  fail_open = var.fail_open

  metadata = merge(
    {
      iapPolicyVersion = "V1"
    },
    var.iap_enforcement_mode != null ? {
      iamEnforcementMode = var.iap_enforcement_mode
    } : {}
  )
}

# IAP Authz Policy on Agent Gateway
resource "google_network_security_authz_policy" "iap" {
  depends_on     = [time_sleep.wait_for_gateway]
  provider       = google-beta
  project        = var.project_id
  name           = "${var.gateway_name}-iap-policy"
  location       = var.gateway_region
  policy_profile = "REQUEST_AUTHZ"
  action         = "CUSTOM"

  target {
    resources = [google_network_services_agent_gateway.this.id]
  }

  custom_provider {
    authz_extension {
      resources = [google_network_services_authz_extension.iap.id]
    }
  }
}
