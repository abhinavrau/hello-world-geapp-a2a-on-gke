# ruff: noqa
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

import datetime
from zoneinfo import ZoneInfo

from google.adk.agents import Agent
from google.adk.apps import App
from google.adk.models import Gemini
from google.genai import types

import os
import google.auth

_, project_id = google.auth.default()
os.environ["GOOGLE_CLOUD_PROJECT"] = project_id or os.getenv("GOOGLE_CLOUD_PROJECT", "")
os.environ["GOOGLE_CLOUD_LOCATION"] = os.getenv("GOOGLE_CLOUD_LOCATION", "us-central1")
os.environ["GOOGLE_GENAI_USE_VERTEXAI"] = "True"


def say_hello(name: str | None = None) -> str:
    """Provides a friendly hello world greeting.

    Args:
        name: Optional name of the person or agent to greet.

    Returns:
        A personalized greeting message from the GKE A2A agent.
    """
    if name:
        return f"Hello, {name}! Welcome to the Hello World A2A Agent on GKE."
    return "Hello, World! Greetings from the A2A Agent running on Google Kubernetes Engine (GKE)."


root_agent = Agent(
    name="root_agent",
    model=Gemini(
        model="gemini-2.5-flash",
        retry_options=types.HttpRetryOptions(attempts=3),
    ),
    instruction="You are a friendly Hello World A2A agent designed to run on Google Kubernetes Engine (GKE). You provide warm greetings to users and communicate with other AI agents via the Agent-to-Agent (A2A) protocol. Use the say_hello tool when asked to greet someone or when introducing yourself.",
    tools=[say_hello],
)

app = App(
    root_agent=root_agent,
    name="app",
)
