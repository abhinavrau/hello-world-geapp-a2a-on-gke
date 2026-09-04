# A2A GKE Agent Gateway Architecture

Context defining the components and domain vocabulary for deploying secure Agent-to-Agent (A2A) services on GKE integrated with Gemini Enterprise via Agent Gateway.

## Language

**Agent Gateway**:
Managed Google Cloud egress gateway providing governed, secure routing (\`AGENT_TO_ANYWHERE\`) from Gemini Enterprise and AI agents into private VPC networks.
_Avoid_: API Gateway, Cloud Endpoints

**Internal Application Load Balancer (Internal ALB)**:
Regional Envoy-based Layer 7 internal load balancer configured with global access (\`allow_global_access = true\`) to receive cross-region traffic from Agent Gateway PSC network attachments.
_Avoid_: External LB, Classic ALB, Ingress Controller

**Standalone NEG**:
A GKE Network Endpoint Group created via pod annotations that maps directly to container endpoints, allowing the Internal ALB to route traffic directly to GKE pods without kube-proxy hops.
_Avoid_: NodePort, ClusterIP LB, Ingress NEG

**Certificate Manager**:
Google Cloud managed certificate service providing regional TLS certificates validated via automated DNS-01 authorizations in Cloud DNS.
_Avoid_: cert-bot, manual GTS script, self-signed cert in prod

**PSC Network Attachment**:
A Private Service Connect network attachment in the customer VPC subnet that allows the Agent Gateway service agent to establish egress interfaces into the VPC.
_Avoid_: PSC Endpoint, VPC Peering

**Authorization Extension (AuthzExtension)**:
A network services resource configuring callouts to authorization services (e.g., Identity-Aware Proxy in \`DRY_RUN\` or \`ENFORCE\` mode) before traffic is forwarded by the Agent Gateway.
_Avoid_: Cloud Armor policy, Istio filter

**Authorization Policy (AuthzPolicy)**:
A network security policy resource bound to the Agent Gateway defining match conditions and enforcement actions.
_Avoid_: Firewall rule, IAM policy

**Agent Registry**:
A central Google Cloud registry where A2A endpoints are cataloged as imported agents for invocation by Gemini Enterprise applications.
_Avoid_: Service Directory, API Catalog

**Workload Project**:
The Google Cloud project hosting the compute backend (GKE Autopilot cluster, Standalone NEGs), private VPC network, Regional Internal ALB, regional TLS certificates, and the PSC Network Attachment.
_Avoid_: Backend project, Provider project

**Consumer Project**:
The Google Cloud project hosting the enterprise AI consumer interface (Gemini Enterprise Discovery Engine App), Agent Gateway, Agent Registry catalog, and Discovery Engine Assistant bindings.
_Avoid_: Frontend project, Client project

**Cross-Project PSC Egress**:
A network architecture where an Agent Gateway in the Consumer Project attaches its egress interfaces to a PSC Network Attachment in the Workload Project with explicit project acceptance whitelisting and scoped `roles/compute.networkUser` IAM permissions.
_Avoid_: Cross-project VPC peering, Shared VPC egress

