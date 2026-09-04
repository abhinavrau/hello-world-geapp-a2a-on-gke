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
echo "Registering A2A Agent in Single-Project Setup"
echo "Project: ${PROJECT_ID} (${PROJECT_NUM})"
echo "GKE Region: ${GKE_REGION}"
echo "Gateway Region: ${GATEWAY_REGION}"
echo "Endpoint: https://${DOMAIN_NAME}/a2a/app"
echo "========================================================================"

AUTH_TOKEN="$(gcloud auth print-access-token)"

echo ""
echo "Step 1: Registering / Updating Service in Agent Registry (${PROJECT_ID})..."
if gcloud alpha agent-registry services describe "${PROJECT_NAME}" --location="${GKE_REGION}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  echo "Agent Registry service already exists. Updating interface URL..."
  gcloud alpha agent-registry services update "${PROJECT_NAME}" \
    --location="${GKE_REGION}" \
    --interfaces="url=https://${DOMAIN_NAME}/a2a/app,protocolBinding=jsonrpc" \
    --project="${PROJECT_ID}"
else
  echo "Creating Agent Registry service..."
  gcloud alpha agent-registry services create "${PROJECT_NAME}" \
    --location="${GKE_REGION}" \
    --display-name="Hello World A2A Service" \
    --description="GKE Hosted A2A Service in ${PROJECT_ID}" \
    --agent-spec-type=no-spec \
    --interfaces="url=https://${DOMAIN_NAME}/a2a/app,protocolBinding=jsonrpc" \
    --project="${PROJECT_ID}"
fi

AGENT_REGISTRY_URN=$(gcloud alpha agent-registry services describe "${PROJECT_NAME}" \
  --location="${GKE_REGION}" \
  --project="${PROJECT_ID}" \
  --format="value(registryResource)")

echo "Agent Registry URN: ${AGENT_REGISTRY_URN}"

echo ""
echo "Step 2: Configuring Agent Gateway on Gemini Enterprise Engine (${ENGINE_ID})..."
curl -s -X PATCH \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -H "X-Goog-User-Project: ${PROJECT_ID}" \
  -H "Content-Type: application/json" \
  "https://discoveryengine.googleapis.com/v1alpha/projects/${PROJECT_NUM}/locations/global/collections/default_collection/engines/${ENGINE_ID}?updateMask=agentGatewaySetting" \
  -d '{
    "agentGatewaySetting": {
      "defaultEgressAgentGateway": {
        "name": "projects/'"${PROJECT_ID}"'/locations/'"${GATEWAY_REGION}"'/agentGateways/'"${GATEWAY_NAME}"'"
      }
    }
  }' > /tmp/ge_gateway_patch.json

echo "Agent Gateway setting updated on Engine."

echo ""
echo "Step 3: Creating Agent Card JSON..."
AGENT_CARD_FILE="/tmp/agent_card_${PROJECT_NAME}.json"
cat << 'EOF' > "${AGENT_CARD_FILE}"
{
  "capabilities": {
    "extensions": [
      {
        "description": "Ability to use the new agent executor implementation",
        "uri": "https://google.github.io/adk-docs/a2a/a2a-extension/"
      }
    ],
    "streaming": true
  },
  "defaultInputModes": ["text/plain"],
  "defaultOutputModes": ["text/plain"],
  "description": "Greets users and provides personalized greetings via GKE and Agent Gateway",
  "name": "hello_world_a2a_agent",
  "preferredTransport": "JSONRPC",
  "protocolVersion": "0.3.0",
  "skills": [
    {
      "description": "An LLM-based agent",
      "id": "root_agent",
      "name": "model",
      "tags": ["llm"]
    },
    {
      "description": "Provides a friendly hello world greeting.",
      "id": "root_agent-say_hello",
      "name": "say_hello",
      "tags": ["llm", "tools"]
    }
  ],
  "supportsAuthenticatedExtendedCard": false,
  "url": "https://DOMAIN_PLACEHOLDER/a2a/app",
  "version": "0.1.0"
}
EOF

sed -i "s/DOMAIN_PLACEHOLDER/${DOMAIN_NAME}/g" "${AGENT_CARD_FILE}"

echo ""
echo "Step 4: Importing Agent into Discovery Engine Assistant..."
IMPORT_RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -H "X-Goog-User-Project: ${PROJECT_ID}" \
  -H "Content-Type: application/json" \
  "https://discoveryengine.googleapis.com/v1alpha/projects/${PROJECT_NUM}/locations/global/collections/default_collection/engines/${ENGINE_ID}/assistants/default_assistant/agents" \
  -d '{
    "displayName": "Hello World GKE",
    "description": "Greets users and provides personalized greetings via GKE and Agent Gateway in '"${PROJECT_ID}"'",
    "importedAgent": {
      "agent": "'"${AGENT_REGISTRY_URN}"'"
    },
    "a2aAgentDefinition": {
      "jsonAgentCard": "'"$(cat "${AGENT_CARD_FILE}" | jq -c . | jq -R . | sed 's/^"//; s/"$//')"' "
    }
  }')

echo "Import Response: ${IMPORT_RESPONSE}"

echo ""
echo "Step 5: Retrieving Discovery Engine Agent ID..."
DISCOVERY_ENGINE_AGENT_ID=$(curl -s -X GET \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -H "X-Goog-User-Project: ${PROJECT_ID}" \
  "https://discoveryengine.googleapis.com/v1alpha/projects/${PROJECT_NUM}/locations/global/collections/default_collection/engines/${ENGINE_ID}/assistants/default_assistant/agents" \
  | jq -r '.agents[] | select(.displayName=="Hello World GKE" or .displayName=="Hello World GKE Multi-Project") | .name | split("/")[-1]' | head -n 1)

echo "========================================================================"
echo "Single-Project Agent Registration Completed Successfully!"
echo "Discovery Engine Agent ID: ${DISCOVERY_ENGINE_AGENT_ID}"
echo "========================================================================"
