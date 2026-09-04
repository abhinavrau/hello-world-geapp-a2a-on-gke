# Modular Terraform Architecture and Google Certificate Manager for A2A GKE

We decided to refactor the flattened Terraform configuration into structured modules aligned with the GCP Cloud Networking Solutions blueprint (`demos/agent-gateway`) and replace manual/scripted Public CA ACME certificates with Google Cloud Certificate Manager DNS authorizations.

## Context
The previous setup relied on a monolithic `service.tf` file and a multi-step manual workflow using a Python ACME script with Google Public CA to generate TLS certificates for the regional Internal Application Load Balancer. Additionally, Agent Gateway and IAP authorization extensions were managed out-of-band via raw `curl` calls.

## Decision
1. **Module Decomposition**: Break down infrastructure into dedicated Terraform modules (`foundation`, `networking`, `gke`, `k8s-app`, `certificates`, `dns`, `internal-lb`, `agent-gateway`, `observability`).
2. **Automated TLS via Certificate Manager**: Use `google_certificate_manager_certificate` and `google_certificate_manager_dns_authorization` integrated with `google_dns_record_set` for 100% declarative, self-renewing TLS certificates attached directly to the regional target HTTPS proxy.
3. **Declarative Agent Gateway**: Codify Agent Gateway, PSC-I network attachments, IAP authorization extensions (`DRY_RUN`), and authorization policies directly in Terraform under `modules/agent-gateway`.
4. **State Migration Support**: Provide Terraform 1.5+ `moved {}` blocks to ensure existing single-project state files migrate cleanly without resource recreation.
