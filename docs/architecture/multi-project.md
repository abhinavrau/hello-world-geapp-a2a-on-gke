# Multi-Project Architecture & Deployment Guide

This document provides the complete architectural design, network flowcharts, cross-project trust models, and operational runbook for deploying the **Agent-to-Agent (A2A)** GKE architecture across a **multi-project enterprise landing zone**:
- **Workload Project (Project A - `your-workload-project-id`)**: Hosts the GKE Autopilot cluster, Standalone NEGs, Regional Internal ALB, Certificate Manager TLS certificates, and PSC Network Attachment.
- **Consumer Project (Project B - `your-consumer-project-id`)**: Hosts the Gemini Enterprise Discovery Engine App, Agent Gateway, Agent Registry catalog, and Cloud DNS managed zone (`your-dns-zone-name`).

---

## 🏛️ Multi-Project Architecture Overview

Separating workload infrastructure from AI consumption is standard in enterprise organizations:
- **Workload Project Team**: Manages container workloads, microservice deployments, VPC routing, and private load balancers.
- **AI Platform / Consumer Team**: Manages Gemini Enterprise assistants, Agent Gateways, access governance, and fleet-wide Agent Registries.

### High-Level Visual

![Multi-Project Architecture](../ge-app-a2a-gke-multi-project.png)

---

## 📊 Detailed Technical Flowchart

```mermaid
flowchart TD
    subgraph ConsumerProj["Consumer Project (Project B: your-consumer-project-id)"]
        subgraph GE["Gemini Enterprise (Discovery Engine)"]
            User(["👤 User Chat / StreamAssist"]) --> Assistant["GE App (Discovery Engine)<br><i>Engine: hello-world-a2a</i>"]
            Assistant -->|1. Imported Agent Resolution| AgentReg["Agent Registry<br><i>projects/your-consumer-project-id/locations/global</i>"]
            Assistant -->|2. Envoy SWP Routing| AGW["Agent Gateway (Egress)<br><b>Region: us-central1</b><br>• Mode: AGENT_TO_ANYWHERE<br>• IAP Authz Policy (DRY_RUN)<br>• SA: service-CONSUMER_PROJECT_NUM@gcp-sa-agentgateway"]
        end
        DNS["Cloud DNS Managed Zone<br><i>your-dns-zone-name</i><br>• FQDN ➔ 10.0.0.10<br>• DNS-01 Challenge CNAME"]
    end

    subgraph WorkloadProj["Workload Project (Project A: your-workload-project-id)"]
        NetAttach["PSC Network Attachment (us-central1)<br><i>hello-world-a2a-net-attachment-egress</i><br>• Subnet: 10.10.0.0/20<br>• <b>connection_preference: ACCEPT_AUTOMATIC</b>"]

        subgraph GKERegion["Region: us-central1 (Workload Region)"]
            subgraph LoadBalancer["Regional Internal HTTPS Load Balancer"]
                FWR["Forwarding Rule<br><b>VIP: 10.0.0.10:443</b><br><i>allowGlobalAccess: true</i><br><i>port_range: 443</i>"]
                Proxy["Target HTTPS Proxy<br><i>Regional Cert (Certificate Manager)</i>"]
                URLMap["Regional URL Map<br><i>Path matcher: /a2a/app/*</i>"]
                BackendSvc["Regional Backend Service<br><i>Health Check: /docs (Port 8080)</i>"]
                ProxySubnet["Proxy-Only Subnet<br><i>10.200.0.0/24</i>"]
                
                FWR --> Proxy --> URLMap --> BackendSvc
                ProxySubnet -.->|Envoy Data Plane| BackendSvc
            end

            subgraph GKECluster["GKE Autopilot Cluster (hello-world-a2a)"]
                NEG["Standalone NEGs (Multi-Zone)<br><i>hello-world-a2a-neg</i>"]
                Pods["A2A Container Pods<br><i>FastAPI / ADK (Port 8080)</i>"]
                BackendSvc -->|Direct Pod IP Routing| NEG --> Pods
            end
        end
    end

    AGW -->|3. Cross-Project PSC Interface Link| NetAttach
    NetAttach -->|4. Global VPC Backbone Routing| FWR
    DNS -.->|DNS-01 Authorization Challenge| Proxy
```

---

## 🔒 Cross-Project Trust & Security Model

The multi-project design establishes a zero-trust cross-project boundary:

1. **Explicit PSC Whitelisting (`ACCEPT_MANUAL`)**:
   - The PSC Network Attachment in Project A does not accept arbitrary connections. It enforces `connection_preference = "ACCEPT_MANUAL"` with `producer_accept_lists = ["your-consumer-project-id"]`.
2. **Scoped IAM Network User Role**:
   - Project A grants `roles/compute.networkUser` on the network attachment subnet strictly to Consumer Project B's Agent Gateway Service Agent:
     `service-CONSUMER_PROJECT_NUM@gcp-sa-agentgateway.iam.gserviceaccount.com`.
3. **Consumer Discovery Engine Permissions**:
   - In Project B, Discovery Engine Service Agent (`service-CONSUMER_PROJECT_NUM@gcp-sa-discoveryengine.iam.gserviceaccount.com`) is granted the custom role `agent_gateway_ge_access` to query the local Agent Gateway and Agent Registry.
4. **Governed Egress & Authorization Extensions**:
   - All outgoing requests from Gemini Enterprise are intercepted by Project B's Agent Gateway and evaluated against IAP / Model Armor authorization policies before entering Project A's VPC.

---

## 📋 Prerequisites

1. **Two Google Cloud Projects**:
   - Workload Project: `your-workload-project-id` (Project Number: `your-workload-project-num`)
   - Consumer Project: `your-consumer-project-id` (Project Number: `your-consumer-project-num`)
2. **IAM Privileges**: Project Owner or Network Admin and Security Admin on both projects.
3. **Active Gemini Enterprise App** in Consumer Project B (`your-consumer-project-id`).
4. **Cloud DNS Managed Zone** in Consumer Project B (`your-dns-zone-name`).

---

## ⚙️ Environment Configuration

Create or update `.env` in the repository root:

```bash
# Workload Project Configuration (Project A)
WORKLOAD_PROJECT_ID="your-workload-project-id"
WORKLOAD_PROJECT_NUM="your-workload-project-num"

# Consumer Project Configuration (Project B)
CONSUMER_PROJECT_ID="your-consumer-project-id"
CONSUMER_PROJECT_NUM="your-consumer-project-num"
DNS_PROJECT_ID="your-consumer-project-id"

# Regional Infrastructure Settings
GKE_REGION="us-central1"
GATEWAY_REGION="us-central1"
GATEWAY_NAME="hello-world-a2a-egress-gateway"
DOMAIN_NAME="hello-world-a2a.yourdomain.com"
DNS_ZONE_NAME="your-dns-zone-name"
ALB_INTERNAL_IP="10.0.0.6"
ENGINE_ID="hello-world-a2a"
PROJECT_NAME="hello-world-a2a"
IMAGE_TAG="v1"
```

Export variables into your active shell session:

```bash
set -a && source .env && set +a
```

---

## 🚀 Step-by-Step Deployment Runbook

### Step 1: Provision Multi-Project Infrastructure with Terraform

The multi-project Terraform configuration (`deployment/terraform/multi-project`) uses dual aliased Google Cloud providers (`google.workload` and `google.consumer`) to orchestrate both projects simultaneously:

1. Navigate to the multi-project directory:
   ```bash
   cd deployment/terraform/multi-project
   ```

2. Review `terraform.tfvars`:
   ```hcl
   workload_project_id   = "your-workload-project-id"
   consumer_project_id   = "your-consumer-project-id"
   dns_project_id        = "your-consumer-project-id"
   project_name          = "hello-world-a2a"
   region                = "us-central1"
   egress_gateway_region = "us-central1"
   domain_name           = "hello-world-a2a.yourdomain.com"
   dns_zone_name         = "your-dns-zone-name"
   enable_create_dns_zone = false
   enable_agent_gateway  = true
   enable_observability  = true
   enable_k8s_workload   = true
   iap_enforcement_mode  = "DRY_RUN"
   fail_open             = true
   ```

3. Initialize and apply:
   ```bash
   export GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token)"
   terraform init
   terraform apply -auto-approve
   ```

---

### Step 2: Build & Deploy Container to GKE in Workload Project

1. Build and push the container image to Artifact Registry in `your-workload-project-id`:
   ```bash
   cd ../../..
   IMAGE_URI="${GKE_REGION}-docker.pkg.dev/${WORKLOAD_PROJECT_ID}/${PROJECT_NAME}/${PROJECT_NAME}:${IMAGE_TAG}"
   gcloud builds submit --project="${WORKLOAD_PROJECT_ID}" --tag "${IMAGE_URI}" .
   ```

2. Update the GKE deployment image:
   ```bash
   ENDPOINT="$(gcloud container clusters describe ${PROJECT_NAME} --region="${GKE_REGION}" --project="${WORKLOAD_PROJECT_ID}" --format='value(endpoint)')"
   TOKEN="$(gcloud auth print-access-token)"

   kubectl --token="${TOKEN}" --server="https://${ENDPOINT}" --insecure-skip-tls-verify \
     set image deployment/${PROJECT_NAME} ${PROJECT_NAME}="${IMAGE_URI}" -n ${PROJECT_NAME}

   kubectl --token="${TOKEN}" --server="https://${ENDPOINT}" --insecure-skip-tls-verify \
     rollout status deployment/${PROJECT_NAME} -n ${PROJECT_NAME} --timeout=180s
   ```

---

### Step 3: Register Agent across Projects into Gemini Enterprise

Execute the automated multi-project registration script:

```bash
./scripts/register_multi_project.sh
```

This automated script:
1. Creates or updates the Service in **Agent Registry** in Consumer Project B (`your-consumer-project-id`).
2. Patches the Discovery Engine Engine in Project B to point `defaultEgressAgentGateway` to Project B's Agent Gateway.
3. Generates the A2A Agent Card JSON referencing `https://${DOMAIN_NAME}/a2a/app`.
4. Imports the agent into the Discovery Engine Assistant (`default_assistant`).

---

## 🔍 Validation & Verification Protocol

Execute the automated health check and verification script:

```bash
./scripts/validate_multi_project.sh
```

### Manual Verification Commands

#### 1. Check GKE Regional ALB Health (Workload Project)
```bash
gcloud compute backend-services get-health hello-world-a2a-backend-service \
  --region=us-central1 \
  --project=your-workload-project-id
```
*Expected*: Health state is `HEALTHY` across active zonal pod endpoints.

#### 2. Check PSC Network Attachment Status (Workload Project)
```bash
gcloud compute network-attachments describe hello-world-a2a-net-attachment-egress \
  --region=us-central1 \
  --project=your-workload-project-id
```
*Expected*: `connectionPreference: ACCEPT_MANUAL`, `producerAcceptLists: [your-consumer-project-id]`.

#### 3. Check Agent Gateway Egress Link (Consumer Project)
```bash
gcloud network-services agent-gateways describe hello-world-a2a-egress-gateway \
  --location=us-central1 \
  --project=your-consumer-project-id
```
*Expected*: `networkAttachment` references `projects/your-workload-project-id/regions/us-central1/networkAttachments/hello-world-a2a-net-attachment-egress`.

#### 4. Test StreamAssist API (Consumer Project ➔ Workload GKE)
```bash
DISCOVERY_ENGINE_AGENT_ID=$(curl -s -X GET \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "X-Goog-User-Project: your-consumer-project-id" \
  "https://discoveryengine.googleapis.com/v1alpha/projects/your-consumer-project-num/locations/global/collections/default_collection/engines/hello-world-a2a/assistants/default_assistant/agents" \
  | jq -r '.agents[] | select(.displayName=="Hello World GKE Multi-Project" or .displayName=="Hello World GKE") | .name | split("/")[-1]' | head -n 1)

curl -N -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "X-Goog-User-Project: your-consumer-project-id" \
  -H "Content-Type: application/json" \
  "https://discoveryengine.googleapis.com/v1alpha/projects/your-consumer-project-num/locations/global/collections/default_collection/engines/hello-world-a2a/assistants/default_assistant:streamAssist" \
  -d '{
    "query": { "text": "Hello Bob! Please say hello back from GKE." },
    "answerGenerationMode": "AGENT",
    "agentsSpec": {
      "agentSpecs": [{ "agentId": "'"${DISCOVERY_ENGINE_AGENT_ID}"'" }],
      "mentionMode": "DIRECT"
    }
  }'
```

---

## 🛠️ Multi-Project Cleanup

To destroy all multi-project resources cleanly:

```bash
cd deployment/terraform/multi-project
export GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token)"
terraform destroy -auto-approve
```
