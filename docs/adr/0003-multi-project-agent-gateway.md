# ADR 0003: Multi-Project Agent Gateway Architecture and Cross-Project PSC Isolation

We decided to support a decoupled multi-project topology separating the Workload/Hosting Project (GKE, VPC, Regional Internal ALB, Certificate Manager, PSC Network Attachment) from the Consumer/Enterprise Project (Gemini Enterprise App, Agent Gateway, Agent Registry), enforcing cross-project PSC security boundaries via explicit producer acceptance whitelisting and scoped IAM roles.

## Context
In enterprise environments, organizations typically separate application workload infrastructure (managed by application and infrastructure engineering teams) from centralized AI and collaboration platforms such as Gemini Enterprise / Discovery Engine (managed by enterprise AI or platform teams). 

In a single-project deployment, the Egress Agent Gateway, VPC Network Attachment, Regional Internal ALB, and GKE Autopilot cluster reside within the same project boundary. To support enterprise landing zones and multi-tenant AI topologies, the architecture must support deploying the A2A agent to a dedicated workload project while enabling discovery, governance, and invocation from a central consumer project.

## Decision
1. **Workload vs Consumer Role Separation**:
   - **Workload Project (Project A)**: Hosts the GKE Autopilot cluster, Standalone NEGs, VPC network, Regional Internal Application Load Balancer with `allow_global_access = true`, regional Certificate Manager certificates, and the PSC Network Attachment in the gateway region.
   - **Consumer Project (Project B)**: Hosts the Gemini Enterprise Discovery Engine App, Agent Gateway (`AGENT_TO_ANYWHERE`), Agent Registry catalog, and Discovery Engine Assistant agent bindings.
   - **DNS Project**: Holds the Cloud DNS managed zone (defaults to Project B or an independent networking project) to handle DNS-01 authorizations and ALB `A` record routing.

2. **Cross-Project Private Service Connect (PSC) Attachment Security**:
   - The PSC Network Attachment in the Workload Project is configured with `connection_preference = "ACCEPT_MANUAL"` and explicitly whitelists the Consumer Project ID in `producer_accept_lists`.
   - The Workload Project grants `roles/compute.networkUser` on the network/subnetwork strictly to the Consumer Project's Agent Gateway service agent (`service-<CONSUMER_PROJECT_NUM>@gcp-sa-agentgateway.iam.gserviceaccount.com`).

3. **Unified Multi-Project Terraform Architecture**:
   - Implement `deployment/terraform/multi-project/` with aliased Google providers (`google.workload` and `google.consumer`) alongside the existing `single-project/` configuration.
   - Outputs from the Workload Project (such as the PSC Network Attachment ID) are passed directly into the Consumer Project's Agent Gateway resource.

4. **Agent Registry & Discovery Engine Integration**:
   - The agent endpoint (`https://<DOMAIN_NAME>/a2a/app`) is registered in the Consumer Project's Agent Registry, creating a registry URN bound to Project B.
   - The Discovery Engine Engine in Project B is patched with `defaultEgressAgentGateway` pointing to the Consumer Project's Agent Gateway.
   - The Discovery Engine Assistant in Project B imports the agent definition referencing the local Agent Registry URN and the A2A agent card.

## Consequences
- **Security & Isolation**: Clear demarcation of responsibilities between workload owners and AI platform admins with strict network isolation.
- **Maintainability**: Infrastructure can be provisioned end-to-end via Terraform while preserving compatibility with existing single-project configurations.
- **Auditability**: Gateway access logs and security policy evaluations are captured within the Consumer Project, while workload execution logs reside in the Workload Project.
