# syntax=docker/dockerfile:1
#
# pi environment image: pi coding agent + pi-config (kkiyama117/pi-config).
#
# The image is secret-free by design (the config repo is secret-free). Pass
# provider API keys at runtime, e.g.:
#
#   podman run --rm -it -e DEEPSEEK_API_KEY ghcr.io/kkiyama117/pi-config:latest
#
# Pull with apptainer (no local podman needed):
#
#   apptainer pull docker://ghcr.io/kkiyama117/pi-config:latest
#
# Build locally:
#
#   podman build -t ghcr.io/kkiyama117/pi-config:latest .
#
# Pin the pi version with: podman build --build-arg PI_VERSION=0.84.0 ...

FROM node:24-bookworm-slim

# pi release to install (npm dist-tag or exact version)
ARG PI_VERSION=latest

RUN apt-get update \
  && apt-get install -y --no-install-recommends bash ca-certificates git ripgrep \
  && rm -rf /var/lib/apt/lists/*

# Official pi install (see pi docs: docs/containerization.md "Plain Docker")
RUN npm install -g --ignore-scripts "@earendil-works/pi-coding-agent@${PI_VERSION}"

# pi-config: reviewable, secret-free config. Runtime layout: the repo is
# cloned into ~/.pi, so COPY . /root/.pi yields /root/.pi/agent/... etc.
COPY . /root/.pi

# Pre-install the packages declared in agent/settings.json (user-level
# installs under /root/.pi/agent/npm; no auth required).
RUN pi install npm:pi-subagents \
 && pi install npm:pi-intercom \
 && pi install npm:pi-prompt-template-model \
 && pi install npm:pi-ollama-cloud \
 && pi install npm:pi-provider-kimi-code \
 && pi install npm:@benvargas/pi-claude-code-use \
 && pi install npm:pi-cursor-sdk \
 && pi install npm:@spences10/pi-skills

WORKDIR /workspace
ENTRYPOINT ["pi"]
