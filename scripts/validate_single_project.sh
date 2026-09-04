#!/usr/bin/env bash
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

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [ -f "${REPO_ROOT}/.env" ]; then
  echo "Loading environment variables from ${REPO_ROOT}/.env..."
  set -a
  source "${REPO_ROOT}/.env"
  set +a
fi

PROJECT_ID="${PROJECT_ID:-your-project-id}"
PROJECT_NUM="${PROJECT_NUM:-your-project-num}"
GKE_REGION="${GKE_REGION:-${REGION:-us-central1}}"
GATEWAY_REGION="${GATEWAY_REGION:-us-central1}"
GATEWAY_NAME="${GATEWAY_NAME:-hello-world-a2a-egress-gateway}"
DOMAIN_NAME="${DOMAIN_NAME:-hello-world-a2a.yourdomain.com}"
ENGINE_ID="${ENGINE_ID:-hello-world-a2a}"
PROJECT_NAME="${PROJECT_NAME:-hello-world-a2a}"

echo "========================================================================"
echo "Single-Project Verification & Health Check"
echo "Project: ${PROJECT_ID} (${PROJECT_NUM})"
echo "========================================================================"

AUTH_TOKEN="$(gcloud auth print-access-token)"

echo ""
echo "--- [1/5] Checking Backend & ALB Health (${PROJECT_ID}) ---"
echo "Backend service health:"
gcloud compute backend-services get-health "${PROJECT_NAME}-backend-service" \
  --region="${GKE_REGION}" \
  --project="${PROJECT_ID}" --format="table(status.healthStatus[0].ipAddress,status.healthStatus[0].healthState)" || echo "Warning: Backend service health query failed."

echo ""
echo "Certificate Manager Regional Certificate status:"
gcloud certificate-manager certificates describe "${PROJECT_NAME}-cert" \
  --location="${GKE_REGION}" \
  --project="${PROJECT_ID}" \
  --format="table(name,managed.state,sanDnsnames)" || echo "Warning: Certificate describe failed."

echo ""
echo "PSC Network Attachment status:"
gcloud compute network-attachments describe "${PROJECT_NAME}-net-attachment-egress" \
  --region="${GATEWAY_REGION}" \
  --project="${PROJECT_ID}" \
  --format="table(name,connectionPreference,producerAcceptLists)" || echo "Warning: Network attachment describe failed."

echo ""
echo "--- [2/5] Checking Agent Gateway (${PROJECT_ID}) ---"
gcloud network-services agent-gateways describe "${GATEWAY_NAME}" \
  --location="${GATEWAY_REGION}" \
  --project="${PROJECT_ID}" \
  --format="yaml(name,networkConfig,registries)" || echo "Warning: Agent gateway describe failed."

echo ""
echo "--- [3/5] Checking Agent Registry (${PROJECT_ID}) ---"
gcloud alpha agent-registry services describe "${PROJECT_NAME}" \
  --location="${GKE_REGION}" \
  --project="${PROJECT_ID}" \
  --format="yaml(name,interfaces,registryResource)" || echo "Warning: Agent Registry service describe failed."

echo ""
echo "--- [4/5] Retrieving Gemini Enterprise Assistant Agent ID ---"
DISCOVERY_ENGINE_AGENT_ID=$(curl -s -X GET \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -H "X-Goog-User-Project: ${PROJECT_ID}" \
  "https://discoveryengine.googleapis.com/v1alpha/projects/${PROJECT_NUM}/locations/global/collections/default_collection/engines/${ENGINE_ID}/assistants/default_assistant/agents" \
  | jq -r '.agents[] | select(.displayName=="Hello World GKE" or .displayName=="Hello World GKE Multi-Project") | .name | split("/")[-1]' | head -n 1)

if [ -z "${DISCOVERY_ENGINE_AGENT_ID}" ] || [ "${DISCOVERY_ENGINE_AGENT_ID}" == "null" ]; then
  echo "Error: Could not find imported agent in Discovery Engine Assistant."
  echo "Run ./scripts/register_single_project.sh first."
  exit 1
fi
echo "Found Discovery Engine Agent ID: ${DISCOVERY_ENGINE_AGENT_ID}"

echo ""
echo "--- [5/5] Invoking Gemini Enterprise StreamAssist API (End-to-End Test) ---"
echo "Sending request to: https://discoveryengine.googleapis.com/v1alpha/projects/${PROJECT_NUM}/.../assistants/default_assistant:streamAssist"
echo ""

curl -N -X POST \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -H "X-Goog-User-Project: ${PROJECT_ID}" \
  -H "Content-Type: application/json" \
  "https://discoveryengine.googleapis.com/v1alpha/projects/${PROJECT_NUM}/locations/global/collections/default_collection/engines/${ENGINE_ID}/assistants/default_assistant:streamAssist" \
  -d '{
    "query": {
      "text": "Hello Bob! Please say hello back from GKE."
    },
    "answerGenerationMode": "AGENT",
    "agentsSpec": {
      "agentSpecs": [
        {
          "agentId": "'"${DISCOVERY_ENGINE_AGENT_ID}"'"
        }
      ],
      "mentionMode": "DIRECT"
    }
  }'

echo ""
echo "========================================================================"
echo "Single-Project Validation Complete!"
echo "========================================================================"
