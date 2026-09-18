# Secure Agent-to-Agent (A2A) on GKE for Gemini Enterprise

A sample reference implementation demonstrating how to deploy, govern, and securely expose  **Agent-to-Agent (A2A)** microservices on **Google Kubernetes Engine (GKE)** to **Gemini Enterprise (Discovery Engine)** applications.

This solution integrates **GKE Autopilot**, **Regional Internal Application Load Balancers (ALBs)** with Standalone Network Endpoint Groups (NEGs), **Google Certificate Manager**, and **Agent Gateway (Egress Gateway)** across both single-project and multi-project enterprise architectures.

---

## 🏛️ High-Level Architecture Overview

This repository supports two architectural topologies depending on your organization's landing zone model:

### 1. Single-Project Architecture 
All infrastructure components—GKE cluster, VPC network, Regional Internal ALB, Certificate Manager, Agent Gateway, Agent Registry, and Gemini Enterprise—reside within a single Google Cloud project.

![Single-Project Architecture](./docs/ge-app-a2a-gke.png)

👉 *For the detailed technical flowchart, component specifications, and step-by-step single-project runbook, see the [Single-Project Architecture Guide](docs/architecture/single-project.md).*

---

### 2. Multi-Project Architecture 
Separates the **Workload Project** (GKE cluster, VPC, Regional Internal ALB, TLS certificates, and Private Service Connect Network Attachment) from the **Consumer Project** (Gemini Enterprise App, Agent Gateway, Agent Registry, and Cloud DNS).

![Multi-Project Architecture](./docs/ge-app-a2a-gke-multi-project.png)

👉 *For the detailed technical flowchart, cross-project PSC security model, and step-by-step multi-project runbook, see the [Multi-Project Architecture Guide](docs/architecture/multi-project.md).*

---

## ⚖️ Architectural Decision Matrix: Single-Project vs. Multi-Project

| Architectural Dimension | Single-Project Topology | Multi-Project Topology |
| :--- | :--- | :--- |
| **Recommended Use Case** | Fast prototyping, sandbox development, self-contained demos |  Centralized AI platforms, multi-tenant organizations |
| **Workload Hosting** | Project A (`your-project-id`) | Project A (`your-workload-project-id`) |
| **AI Platform / Gemini Enterprise** | Project A (`your-project-id`) | Project B (`your-consumer-project-id`) |
| **Agent Gateway Location** | Project A (attached to local VPC) | Project B (attached to Project A via cross-project PSC) |
| **Network Boundary** | Shared local VPC | Cross-project PSC interface with `ACCEPT_MANUAL` producer whitelisting |
| **IAM Trust Boundary** | Internal project service agents | Scoped cross-project `roles/compute.networkUser` grants |
| **Terraform Configuration** | `deployment/terraform/single-project` | `deployment/terraform/multi-project` (dual aliased providers) |
| **Registration Workflow** | In-cluster GKE auto-registration (`registry.gke.io/functional-type: "AGENT"`) + GE binding script (`scripts/register_single_project.sh`) | Local GKE auto-registration (Workload Project) + cross-project registration script (`scripts/register_multi_project.sh`) |

### ⚙️ Environment Variables Reference Matrix

The table below details all environment variables used by Terraform, Cloud Build, deployment commands, and registration/validation scripts:

| Environment Variable | Single-Project | Multi-Project | Default Value | Used By | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `PROJECT_ID` | **Required** | *Not Used* | — | Terraform, Build, Scripts | Main GCP project hosting GKE, ALB, and Gemini Enterprise |
| `PROJECT_NUM` | **Required** | *Not Used* | — | Scripts (`register`, `validate`) | Numeric project number (required for Discovery Engine REST APIs) |
| `WORKLOAD_PROJECT_ID` | *Not Used* | **Required** | — | Terraform, Build, Scripts | Project A hosting GKE cluster, VPC, ALB, and PSC Network Attachment |
| `CONSUMER_PROJECT_ID` | *Not Used* | **Required** | — | Terraform, Scripts | Project B hosting Discovery Engine App, Agent Gateway, and Catalog |
| `CONSUMER_PROJECT_NUM` | *Not Used* | **Required** | — | Scripts (`register`, `validate`) | Numeric project number of Project B for Discovery Engine REST APIs |
| `DOMAIN_NAME` | **Required** | **Required** | — | Terraform, Pod Env, Scripts | Fully qualified domain name pointing to Regional Internal ALB VIP |
| `DNS_ZONE_NAME` | **Required** | **Required** | — | Terraform | Cloud DNS managed zone name (for ALB `A` record and DNS-01 ACME cert challenge) |
| `DNS_PROJECT_ID` | Optional | Optional | `PROJECT_ID` / `CONSUMER_PROJECT_ID` | Terraform | Project hosting the Cloud DNS zone |
| `ENGINE_ID` | **Required** | **Required** | — | Scripts (`register`, `validate`) | Discovery Engine App / Engine ID in Gemini Enterprise |
| `ALB_INTERNAL_IP` | Optional | Optional | `10.0.0.10` (Single) / `10.0.0.6` (Multi) | Terraform | Reserved private RFC 1918 VIP assigned to Regional Internal ALB |
| `GKE_REGION` | Optional | Optional | `us-central1` | Terraform, Build, Scripts | Workload region (must match `GATEWAY_REGION` for PSC dynamic interface) |
| `GATEWAY_REGION` | Optional | Optional | `us-central1` | Terraform, Scripts | Egress Agent Gateway region (must match `GKE_REGION`) |
| `GATEWAY_NAME` | Optional | Optional | `hello-world-a2a-egress-gateway` | Terraform, Scripts | Egress Agent Gateway resource name |
| `PROJECT_NAME` | Optional | Optional | `hello-world-a2a` | Terraform, Scripts | Common resource naming prefix for cluster, certs, and NEGs |
| `IMAGE_TAG` | Optional | Optional | `v1` | Cloud Build, Kubectl | Container image version tag |

👉 *Template files are provided in the repository root: [`.env.single-project.example`](.env.single-project.example) and [`.env.multi-project.example`](.env.multi-project.example).*

---

## 🏛️ Key Technical Pillars

1. **Modular Infrastructure via Terraform**:
   Decomposed into 9 decoupled modules (`foundation`, `networking`, `gke`, `k8s-app`, `certificates`, `dns`, `internal-lb`, `agent-gateway`, `observability`) following the Google Cloud Networking reference architecture.
2. **GKE Autopilot & Standalone NEGs**:
   The agent container runs on GKE Autopilot. Kubernetes Services utilize Standalone Network Endpoint Groups (`cloud.google.com/neg`) allowing the Regional Internal ALB to route traffic directly to container Pod IPs across active zones without kube-proxy hops.
3. **Regional Co-Location with PSC Network Attachment**:
   Dynamic Private Service Connect interfaces (PSC-I / Network Attachments) used by Google Agent Gateway require the consumer Gateway, Network Attachment, and target Regional Internal Application Load Balancer to reside within the **same Google Cloud region** (e.g. `us-central1`). Cross-region egress from PSC-I dynamic interfaces to a regional ILB in another region is dropped at the data plane.
4. **Declarative Google Certificate Manager**:
   Google Agent Gateway validates TLS certificates against trusted public CAs. Regional Google-managed certificates are provisioned via Certificate Manager with automated DNS-01 authorizations in Cloud DNS directly in Terraform.
5. **Agent Gateway & DNS Architecture**:
   The Agent Gateway uses a Private Service Connect (PSC) network attachment for VPC egress and resolves public DNS records natively through Google's public resolver while routing payloads through private VPC interfaces.
6. **GKE In-Cluster Agent Auto-Registration & Dynamic Skill Discovery**:
   Workloads on GKE Autopilot are annotated with `registry.gke.io/functional-type: "AGENT"` and `a2a-protocol.org/agent-card` per the [Google Cloud Agent Registry GKE Auto-Registration specification](https://docs.cloud.google.com/agent-registry/automatic-registration#gke). The GKE runtime controller introspects `/.well-known/agent-card.json` directly from the pod on port 8080 to dynamically register the agent and its live skills into Google Cloud Agent Registry, eliminating configuration drift when tools change.

---

## 📂 Repository Layout

```
.
├── .env.single-project.example             # Environment template for single-project stack
├── .env.multi-project.example              # Environment template for multi-project stack
├── app/                                    # A2A Agent application source code (FastAPI, ADK, JSON-RPC)
├── deployment/
│   ├── terraform/
│   │   ├── modules/                        # Decoupled Terraform infrastructure modules
│   │   │   ├── foundation/                 # APIs, Service Accounts, Base IAM
│   │   │   ├── networking/                 # VPC, Subnets, Cloud NAT, PSC Network Attachment
│   │   │   ├── gke/                        # GKE Autopilot Cluster, Artifact Registry
│   │   │   ├── k8s-app/                    # Kubernetes Service, Deployment, HPA, PDB
│   │   │   ├── certificates/               # Google Certificate Manager Regional Certs
│   │   │   ├── dns/                        # Cloud DNS challenge & ALB A records
│   │   │   ├── internal-lb/                # Regional Internal ALB, URL Map, Standalone NEGs
│   │   │   ├── agent-gateway/              # Egress Agent Gateway, IAP Authz Extension & Policy
│   │   │   └── observability/              # BigQuery telemetry dataset, Logging sinks
│   │   ├── single-project/                 # Single-project root Terraform configuration
│   │   └── multi-project/                  # Multi-project root Terraform configuration (dual providers)
├── docs/
│   ├── architecture/
│   │   ├── single-project.md               # Detailed single-project flowchart & operational runbook
│   │   └── multi-project.md                # Detailed multi-project flowchart & operational runbook
│   ├── adr/                                # Architectural Decision Records (0001, 0002, 0003, 0004)
│   └── production-security-guide.md        # Hardening guide (Active IAP, Model Armor, VPC-SC)
├── scripts/
│   ├── register_single_project.sh          # Automated single-project registration in Agent Registry & GE
│   ├── validate_single_project.sh          # End-to-end single-project health checks & StreamAssist verification
│   ├── register_multi_project.sh           # Automated multi-project registration in Agent Registry & GE
│   └── validate_multi_project.sh           # End-to-end multi-project health checks & StreamAssist verification
└── tests/                                  # Unit and integration test suites
```

---

## ⚡ Quickstart

### Option A: Deploy Single-Project Stack
For local sandboxes and self-contained testing within a single GCP project:

```bash
# 0. Configure Environment
cp .env.single-project.example .env
# Edit .env with your PROJECT_ID, PROJECT_NUM, DOMAIN_NAME, DNS_ZONE_NAME, ENGINE_ID
set -a && source .env && set +a

# 1. Provision Single-Project Infrastructure
cd deployment/terraform/single-project
cp terraform.tfvars.example terraform.tfvars
# Update terraform.tfvars to match your .env configuration
terraform init && terraform apply -auto-approve

# 2. Build & Deploy Container Image
cd ../../..
IMAGE_URI="${GKE_REGION}-docker.pkg.dev/${PROJECT_ID}/${PROJECT_NAME}/${PROJECT_NAME}:${IMAGE_TAG}"
gcloud builds submit --project="${PROJECT_ID}" --tag "${IMAGE_URI}" .

# 3. Bind Auto-Registered Agent to Gemini Enterprise
# (GKE controller auto-registers the agent and dynamic skills; this script links it to GE)
./scripts/register_single_project.sh

# 4. Run End-to-End Validation
./scripts/validate_single_project.sh
```
👉 *Read the full [Single-Project Architecture & Deployment Guide](docs/architecture/single-project.md).*

---

### Option B: Deploy Multi-Project Stack
For enterprise architectures separating workload hosting from Gemini Enterprise:

```bash
# 0. Configure Environment
cp .env.multi-project.example .env
# Edit .env with WORKLOAD_PROJECT_ID, CONSUMER_PROJECT_ID, CONSUMER_PROJECT_NUM, DOMAIN_NAME, etc.
set -a && source .env && set +a

# 1. Provision Multi-Project Infrastructure (Workload + Consumer Projects)
cd deployment/terraform/multi-project
cp terraform.tfvars.example terraform.tfvars
# Update terraform.tfvars to match your .env configuration
terraform init && terraform apply -auto-approve

# 2. Build & Deploy Container Image to Workload Project
cd ../../..
IMAGE_URI="${GKE_REGION}-docker.pkg.dev/${WORKLOAD_PROJECT_ID}/${PROJECT_NAME}/${PROJECT_NAME}:${IMAGE_TAG}"
gcloud builds submit --project="${WORKLOAD_PROJECT_ID}" --tag "${IMAGE_URI}" .

# 3. Register Service across Projects & Bind to Gemini Enterprise
# (GKE auto-registers in Workload Project; this script bridges cataloging to Consumer Project & GE)
./scripts/register_multi_project.sh

# 4. Run End-to-End Validation
./scripts/validate_multi_project.sh
```
👉 *Read the full [Multi-Project Architecture & Deployment Guide](docs/architecture/multi-project.md).*

---

## 📚 Documentation & Reference Guides

- 📖 **[Single-Project Architecture Guide](docs/architecture/single-project.md)**: Deep-dive flowchart, packet flow sequence, and single-project runbook.
- 📖 **[Multi-Project Architecture Guide](docs/architecture/multi-project.md)**: Deep-dive flowchart, cross-project PSC security model, and multi-project runbook.
- 🛡️ **[Production Security & Authorization Guide](docs/production-security-guide.md)**: Enforcing active IAP, Model Armor content filtering, mTLS, and VPC Service Controls.
- 🌐 **[Google Cloud Agent Registry: Automatic Registration on GKE](https://docs.cloud.google.com/agent-registry/automatic-registration#gke)**: Official documentation on GKE in-cluster workload introspection and agent registration.
- 📐 **Architectural Decision Records (ADRs)**:
  - [ADR 0001: Modular Terraform & Certificate Manager](docs/adr/0001-modular-terraform-and-certificate-manager.md)
  - [ADR 0002: Internal ALB & Dynamic Multi-Zone NEGs](docs/adr/0002-internal-alb-and-dns-design.md)
  - [ADR 0003: Multi-Project Agent Gateway Architecture](docs/adr/0003-multi-project-agent-gateway.md)
  - [ADR 0004: GKE In-Cluster Agent Auto-Registration & Dynamic Skill Discovery](docs/adr/0004-gke-agent-auto-registration.md)

---

## 📄 License

Copyright 2026 Google LLC. Licensed under the Apache License, Version 2.0.
