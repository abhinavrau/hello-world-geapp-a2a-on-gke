# AGENTS.md

Conventions, operational guardrails, ADK lifecycle patterns, and architectural invariants for agents in this repository.

See [`README.md`](README.md) for full infrastructure architecture, deployment steps, and log queries.

---

## Operational Rules

- **Code Preservation**: Modify only code directly targeted by the request. Preserve surrounding code, comments, configurations, and formatting.
- **Model Invariant**: Do not change the model name (e.g. `gemini-2.5-flash`) unless requested. For model 404 errors, check `GOOGLE_CLOUD_LOCATION` (e.g., `global` vs. `us-east1`).
- **Python Execution**: Run Python commands with `uv`:
  ```bash
  uv run python script.py
  uv run pytest tests/unit tests/integration
  ```
- **ADK Tool Imports**: Import the tool instance directly: `from google.adk.tools.load_web_page import load_web_page`.
- **Error Resolution**: If an operation fails repeatedly with the same error, identify the root cause instead of retrying. For Terraform 409 resource conflicts, use `terraform import`.
- **Environment Placeholders**: Use generic placeholders (`your-project-id`, `your-domain.com`) in documentation and sample code; do not commit specific project IDs or usernames.

---

## Authentication and Environment

1. **Environment Initialization**:
   ```bash
   set -a && source .env && set +a
   ```
2. **Access Token Export**:
   Export OAuth token prior to running `terraform` or `kubectl` commands to prevent `USER_PROJECT_DENIED` 403 errors:
   ```bash
   export GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token)"
   ```
3. **Discovery Engine Quota Headers**:
   REST requests to `discoveryengine.googleapis.com` must include:
   ```bash
   -H "X-Goog-User-Project: ${PROJECT_ID}"
   ```

---

## Architectural Invariants

| Component | Invariant | Failure Mode If Violated |
| :--- | :--- | :--- |
| **Forwarding Rule** | `allow_global_access = true` in `modules/internal-lb` | `HTTP 504: upstream request timeout` (cross-region traffic from Agent Gateway dropped) |
| **Forwarding Rule Port** | `port_range = "443"` (not `ports = ["443"]`) | Terraform provider schema validation error on `TargetHttpsProxy` |
| **Agent Gateway DNS** | Omit `dns_peering_config` for public Cloud DNS domains | `Config validation failed: domain does not exist as private zone` |
| **GKE Standalone NEG** | Reference only active zones (`local.neg_zones`) in Backend Service | `404 Not Found` during apply (NEGs only exist in zones with scheduled Pods) |
| **Certificate Manager** | Google-managed regional certificates with DNS-01 Cloud DNS authorization | TLS handshake failures / untrusted cert errors on Agent Gateway |
| **Agent Gateway Security** | Attach Authorization Extension & Policy to Egress Gateway (`DRY_RUN` in dev, `ENFORCE` in prod) | `HTTP 403: Access denied (default_denied)` on Agent Gateway invocation |

---

## ADK Development and Evaluation Lifecycle

### 1. Development and Local Testing
- Agent definitions reside under `app/`.
- Interactive testing:
  ```bash
  agents-cli playground
  ```

### 2. Evaluation Loop
- Synthesize eval scenarios:
  ```bash
  agents-cli eval dataset synthesize
  ```
- Generate traces and score agent responses:
  ```bash
  agents-cli eval generate
  agents-cli eval grade
  ```
- Compare results and analyze failure clusters:
  ```bash
  agents-cli eval compare
  agents-cli eval analyze
  ```
- Auto-tune prompts:
  ```bash
  agents-cli eval optimize
  ```

### 3. Pre-Deployment Verification
- Run tests and linting:
  ```bash
  uv run pytest tests/unit tests/integration
  agents-cli lint
  ```

---

## Deployment and Verification References

- **Infrastructure Provisioning**: [`README.md` (Step 1)](README.md#step-1-provision-infrastructure-with-modular-terraform)
- **Container Rollout**: [`README.md` (Step 2)](README.md#step-2-build-and-deploy-the-container-to-gke)
- **Agent Registry and Discovery Engine**: [`README.md` (Steps 3 and 4)](README.md#step-3-register-the-service-in-agent-registry)
- **Verification**: [`README.md` (Verification)](README.md#-verification--testing)
- **Production Hardening**: [`docs/production-security-guide.md`](docs/production-security-guide.md)
