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

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0, < 8.0.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.0.0, < 8.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.37.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.10.0"
    }
  }
}

# Default provider (defaults to Workload Project)
provider "google" {
  project = var.workload_project_id
  region  = var.region
}

provider "google-beta" {
  project = var.workload_project_id
  region  = var.region
}

# Aliased Provider for Workload Project (GKE, VPC, ILB, Certs, PSC Network Attachment)
provider "google" {
  alias   = "workload"
  project = var.workload_project_id
  region  = var.region
}

provider "google-beta" {
  alias   = "workload"
  project = var.workload_project_id
  region  = var.region
}

# Aliased Provider for Consumer Project (Gemini Enterprise App, Agent Gateway, Agent Registry)
provider "google" {
  alias   = "consumer"
  project = var.consumer_project_id
  region  = var.egress_gateway_region
}

provider "google-beta" {
  alias   = "consumer"
  project = var.consumer_project_id
  region  = var.egress_gateway_region
}

# Aliased Provider for Cloud DNS Project (if separate)
provider "google" {
  alias   = "dns"
  project = coalesce(var.dns_project_id, var.consumer_project_id)
  region  = var.region
}

provider "google-beta" {
  alias   = "dns"
  project = coalesce(var.dns_project_id, var.consumer_project_id)
  region  = var.region
}

data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${module.gke.cluster_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
}
