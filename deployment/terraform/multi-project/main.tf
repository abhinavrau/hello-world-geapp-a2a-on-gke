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

# ==============================================================================
# Phase 1: Foundation (APIs and IAM for both Projects)
# ==============================================================================

# Workload Project Foundation (APIs, Compute SA role)
module "foundation_workload" {
  source     = "../modules/foundation"
  project_id = var.workload_project_id
  providers = {
    google      = google.workload
    google-beta = google-beta.workload
  }
}

# Consumer Project Foundation (APIs, Discovery Engine & Agent Gateway prerequisites)
module "foundation_consumer" {
  source     = "../modules/foundation"
  project_id = var.consumer_project_id
  providers = {
    google      = google.consumer
    google-beta = google-beta.consumer
  }
}

# ==============================================================================
# Phase 2: Workload Networking & Cross-Project PSC Attachment
# ==============================================================================

module "networking" {
  source                = "../modules/networking"
  project_id            = var.workload_project_id
  project_name          = var.project_name
  region                = var.region
  egress_gateway_region = var.egress_gateway_region
  connection_preference = "ACCEPT_AUTOMATIC"
  producer_accept_list  = []

  providers = {
    google = google.workload
  }

  depends_on = [module.foundation_workload]
}

# Grant Consumer Agent Gateway Service Agent permission to attach interfaces in Workload Project
resource "google_project_iam_member" "consumer_agent_gateway_network_user" {
  provider = google.workload
  project  = var.workload_project_id
  role     = "roles/compute.networkUser"
  member   = "serviceAccount:service-${module.foundation_consumer.project_number}@gcp-sa-agentgateway.iam.gserviceaccount.com"

  depends_on = [
    module.foundation_workload,
    module.foundation_consumer,
    module.networking
  ]
}

# ==============================================================================
# Phase 3: Observability (Workload Project BigQuery & Telemetry)
# ==============================================================================

module "observability" {
  count                = var.enable_observability ? 1 : 0
  source               = "../modules/observability"
  project_id           = var.workload_project_id
  project_name         = var.project_name
  region               = var.region
  feedback_logs_filter = var.feedback_logs_filter

  providers = {
    google = google.workload
  }

  depends_on = [module.foundation_workload]
}

# ==============================================================================
# Phase 4: GKE Autopilot Cluster & Artifact Registry (Workload Project)
# ==============================================================================

module "gke" {
  source          = "../modules/gke"
  project_id      = var.workload_project_id
  project_name    = var.project_name
  region          = var.region
  network_name    = module.networking.network_name
  subnetwork_name = module.networking.gke_subnet_name
  node_locations  = var.cluster_zones
  app_sa_roles    = var.app_sa_roles

  providers = {
    google = google.workload
  }

  depends_on = [module.foundation_workload, module.networking]
}

# ==============================================================================
# Phase 5: Kubernetes Workload (Namespace, Standalone NEG, Deployment)
# ==============================================================================

module "k8s_app" {
  count            = var.enable_k8s_workload ? 1 : 0
  source           = "../modules/k8s-app"
  project_id       = var.workload_project_id
  project_name     = var.project_name
  logs_bucket_name = var.enable_observability ? module.observability[0].logs_bucket_name : ""

  depends_on = [module.gke]
}

# ==============================================================================
# Phase 6: Certificates (Certificate Manager in Workload Project)
# ==============================================================================

module "certificates" {
  source       = "../modules/certificates"
  project_id   = var.workload_project_id
  project_name = var.project_name
  region       = var.region
  domain_name  = var.domain_name

  providers = {
    google = google.workload
  }

  depends_on = [module.foundation_workload]
}

# ==============================================================================
# Phase 7: DNS Records (Cloud DNS Managed Zone in DNS/Consumer Project)
# ==============================================================================

module "dns" {
  source                   = "../modules/dns"
  project_id               = var.workload_project_id
  dns_project_id           = coalesce(var.dns_project_id, var.consumer_project_id)
  dns_zone_name            = var.dns_zone_name
  domain_name              = var.domain_name
  enable_create_dns_zone   = var.enable_create_dns_zone
  dns_resource_record_name = module.certificates.dns_resource_record_name
  dns_resource_record_type = module.certificates.dns_resource_record_type
  dns_resource_record_data = module.certificates.dns_resource_record_data
  alb_internal_ip          = module.internal_lb.internal_ip

  providers = {
    google = google.dns
  }

  depends_on = [module.foundation_workload, module.certificates]
}

# ==============================================================================
# Phase 8: Regional Internal ALB (Workload Project)
# ==============================================================================

module "internal_lb" {
  source          = "../modules/internal-lb"
  project_id      = var.workload_project_id
  project_name    = var.project_name
  region          = var.region
  network_id      = module.networking.network_id
  subnetwork_id   = module.networking.gke_subnet_id
  proxy_subnet_id = module.networking.proxy_subnet_id
  neg_name        = "${var.project_name}-neg"
  neg_zones       = var.cluster_zones
  certificate_id  = module.certificates.certificate_id

  providers = {
    google = google.workload
  }

  depends_on = [
    module.networking,
    module.certificates,
    module.gke,
    module.k8s_app
  ]
}

# ==============================================================================
# Phase 9: Agent Gateway & Security Policies (Consumer Project)
# ==============================================================================

module "agent_gateway" {
  count                    = var.enable_agent_gateway ? 1 : 0
  source                   = "../modules/agent-gateway"
  project_id               = var.consumer_project_id
  project_number           = module.foundation_consumer.project_number
  registry_project_id      = var.consumer_project_id
  gateway_name             = "${var.project_name}-egress-gateway"
  gateway_region           = var.egress_gateway_region
  network_self_link        = ""
  egress_net_attachment_id = module.networking.egress_net_attachment_id
  dns_peering_domains      = []
  iap_enforcement_mode     = var.iap_enforcement_mode
  fail_open                = var.fail_open

  providers = {
    google      = google.consumer
    google-beta = google-beta.consumer
  }

  depends_on = [
    module.foundation_consumer,
    google_project_iam_member.consumer_agent_gateway_network_user,
    module.internal_lb
  ]
}
