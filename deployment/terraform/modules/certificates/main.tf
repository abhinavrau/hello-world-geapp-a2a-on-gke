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
  domain_name_clean = trimsuffix(var.domain_name, ".")
  domain_auth_name  = replace(local.domain_name_clean, ".", "-")
}

# Regional DNS Authorization for domain validation
resource "google_certificate_manager_dns_authorization" "dns_auth" {
  name        = "${substr(local.domain_auth_name, 0, 50)}-auth"
  location    = var.region
  project     = var.project_id
  domain      = local.domain_name_clean
  description = "Regional DNS authorization for ${local.domain_name_clean}"
  labels      = var.labels
}

# Regional Google-managed certificate issued via DNS Authorization
resource "google_certificate_manager_certificate" "regional" {
  name        = "${var.project_name}-cert"
  location    = var.region
  project     = var.project_id
  description = "Regional Certificate Manager certificate for ${local.domain_name_clean}"

  managed {
    domains = [local.domain_name_clean]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.dns_auth.id
    ]
  }

  labels = var.labels

  lifecycle {
    create_before_destroy = true
  }
}
