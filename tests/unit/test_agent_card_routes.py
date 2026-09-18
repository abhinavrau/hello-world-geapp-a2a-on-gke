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

import pytest
from fastapi.testclient import TestClient

from app.fast_api_app import app


def test_agent_card_endpoints() -> None:
    """Verify that both root and app-prefixed agent card endpoints are served."""
    with TestClient(app) as client:
        root_resp = client.get("/.well-known/agent-card.json")
        assert root_resp.status_code == 200
        root_data = root_resp.json()

        app_resp = client.get("/a2a/app/.well-known/agent-card.json")
        assert app_resp.status_code == 200
        app_data = app_resp.json()

        # Both endpoints should serve matching agent card definitions
        assert root_data["name"] == app_data["name"]
        assert root_data["skills"] == app_data["skills"]
        assert root_data["protocolVersion"] == "0.3.0"
        assert len(root_data["skills"]) > 0
