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

# Phase 1: Foundation (APIs, Project Numbers, Base IAM)
module "foundation" {
  source     = "../modules/foundation"
  project_id = var.project_id
}

# Phase 2: Networking (VPC, Subnets, Firewalls, Cloud NAT, PSC Egress)
module "networking" {
  source                = "../modules/networking"
  project_id            = var.project_id
  project_name          = var.project_name
  region                = var.region
  egress_gateway_region = var.egress_gateway_region

  depends_on = [module.foundation]
}

# Phase 3: Observability (BigQuery, Logging Sinks, Telemetry View)
module "observability" {
  count                = var.enable_observability ? 1 : 0
  source               = "../modules/observability"
  project_id           = var.project_id
  project_name         = var.project_name
  region               = var.region
  feedback_logs_filter = var.feedback_logs_filter

  depends_on = [module.foundation]
}

# Phase 4: GKE Autopilot Cluster & Artifact Registry
module "gke" {
  source          = "../modules/gke"
  project_id      = var.project_id
  project_name    = var.project_name
  region          = var.region
  network_name    = module.networking.network_name
  subnetwork_name = module.networking.gke_subnet_name
  app_sa_roles    = var.app_sa_roles

  depends_on = [module.foundation, module.networking]
}

# Phase 5: Kubernetes Workload (Namespace, Service with Standalone NEG, Deployment)
module "k8s_app" {
  count            = var.enable_k8s_workload ? 1 : 0
  source           = "../modules/k8s-app"
  project_id       = var.project_id
  project_name     = var.project_name
  logs_bucket_name = var.enable_observability ? module.observability[0].logs_bucket_name : ""

  depends_on = [module.gke]
}

# Phase 6: Certificates (Certificate Manager Regional Certificate & DNS Authorization)
module "certificates" {
  source       = "../modules/certificates"
  project_id   = var.project_id
  project_name = var.project_name
  region       = var.region
  domain_name  = var.domain_name

  depends_on = [module.foundation]
}

# Phase 7: DNS (Cloud DNS Record Sets: Challenge CNAME & ALB A Record)
module "dns" {
  source                   = "../modules/dns"
  project_id               = var.project_id
  dns_project_id           = var.dns_project_id
  dns_zone_name            = var.dns_zone_name
  domain_name              = var.domain_name
  enable_create_dns_zone   = var.enable_create_dns_zone
  dns_resource_record_name = module.certificates.dns_resource_record_name
  dns_resource_record_type = module.certificates.dns_resource_record_type
  dns_resource_record_data = module.certificates.dns_resource_record_data
  alb_internal_ip          = module.internal_lb.internal_ip

  depends_on = [module.foundation, module.certificates]
}

# Phase 8: Internal Application Load Balancer (Health Check, Multi-Zone NEG Backend, HTTPS Proxy, Global FR)
module "internal_lb" {
  source          = "../modules/internal-lb"
  project_id      = var.project_id
  project_name    = var.project_name
  region          = var.region
  network_id      = module.networking.network_id
  subnetwork_id   = module.networking.gke_subnet_id
  proxy_subnet_id = module.networking.proxy_subnet_id
  neg_name        = "${var.project_name}-neg"
  certificate_id  = module.certificates.certificate_id

  depends_on = [
    module.networking,
    module.certificates,
    module.gke,
    module.k8s_app
  ]
}

# Phase 9: Agent Gateway (Governed AGENT_TO_ANYWHERE, PSC Egress, IAP Authz Extension & Policy)
module "agent_gateway" {
  count                    = var.enable_agent_gateway ? 1 : 0
  source                   = "../modules/agent-gateway"
  project_id               = var.project_id
  project_number           = module.foundation.project_number
  gateway_name             = "${var.project_name}-egress-gateway"
  gateway_region           = var.egress_gateway_region
  network_self_link        = module.networking.network_self_link
  egress_net_attachment_id = module.networking.egress_net_attachment_id
  dns_peering_domains      = []
  iap_enforcement_mode     = var.iap_enforcement_mode
  fail_open                = var.fail_open

  depends_on = [
    module.foundation,
    module.networking,
    module.internal_lb
  ]
}
