# ADR 0004: GKE In-Cluster Agent Auto-Registration & Dynamic Skill Discovery

We decided to enable GKE in-cluster agent auto-registration unconditionally in the Kubernetes workload module using the `registry.gke.io/functional-type: "AGENT"` label and `a2a-protocol.org/agent-card` annotation, expose a root `/.well-known/agent-card.json` endpoint with an injected `APP_URL`, and maintain cross-project registration scripting for multi-project topologies.

## Context
Previously, registering the A2A agent into Google Cloud Agent Registry required executing bash scripts (`scripts/register_single_project.sh`) that manually called `gcloud alpha agent-registry services create` with `--agent-spec-type=no-spec` and constructed a static, hardcoded Agent Card JSON. This approach created configuration drift whenever ADK agent tools or skills were updated in `app/agent.py`.

Google Cloud Agent Registry supports automatic registration on Google Kubernetes Engine (GKE) where the cluster runtime controller introspects workload pods directly via HTTP and syncs the agent's live skills and metadata into the project's Agent Registry. However, automatic registration only operates within a single Google Cloud project and requires the introspected card to advertise an externally callable endpoint reachable by Gemini Enterprise via Agent Gateway.

## Decision
1. **Unconditional Workload Auto-Registration**:
   - The `k8s-app` Terraform module adds `registry.gke.io/functional-type = "AGENT"` and the `a2a-protocol.org/agent-card` annotation pointing to `endpoint: /.well-known/agent-card.json` on port 8080.
   - The container environment receives `APP_URL = "https://${var.domain_name}"` to ensure the introspected agent card advertises the routable Regional Internal ALB domain.

2. **Standardized Root Agent Card Endpoint**:
   - Expose `/.well-known/agent-card.json` alongside `/a2a/app/.well-known/agent-card.json` in the FastAPI application to adhere to standard A2A discovery specifications.

3. **Topology-Aware Registration Workflow**:
   - **Single-Project Topology**: `scripts/register_single_project.sh` polls for the auto-registered `Agent` in Agent Registry, uses its URN directly for Gemini Enterprise Assistant import, and falls back to explicit `Service` creation if the controller reconciliation has not completed.
   - **Multi-Project Topology**: Because GKE auto-registration cannot cross project boundaries to register into the Consumer Project, `scripts/register_multi_project.sh` continues to explicitly register the cross-project service into the Consumer Project's Agent Registry while the Workload Project benefits from local GKE cataloging.

## Consequences
- **Elimination of Skill Drift**: Changes to ADK tools in `app/agent.py` automatically reflect in Agent Registry upon deployment without script modification.
- **Declarative Infrastructure**: Workload registration is managed as code within Kubernetes manifests rather than imperative CLI commands.
- **Topology Demarcation**: Preserves multi-project landing zone boundaries without sacrificing single-project zero-touch discovery.
