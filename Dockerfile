# syntax=docker/dockerfile:1
FROM debian:bookworm-slim@sha256:88200866dfff7ea7f5cbcb6ec7c8a701889efe6fe859fe64d6990e4b07ea4171

ARG FLYCTL_VERSION=0.4.95
ARG FLYCTL_SHA256=580cbc80b2ce9f28350fd9a1638b44db0e9919338e179b263209035299c0a0e0
ARG GH_VERSION=2.98.0
ARG GH_SHA256=3b8ac6b30336802fc1a858d7c084e11cdf24ac1a761ca90b68022d7d729208de
ARG NODE_VERSION=24.18.0
ARG NODE_SHA256=55aa7153f9d88f28d765fcdad5ae6945b5c0f98a36881703817e4c450fa76742
ARG CLAUDE_CODE_VERSION=2.1.251
ARG CLOUDCLI_VERSION=1.37.3
ARG DNSCONTROL_VERSION=4.44.1
ARG DNSCONTROL_SHA256=cd8f50de158ba1a8b3b4dd52e388f009f235f2f38a3e53c22b39a4bee038c684

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git jq less openssh-client procps python3 vim xz-utils \
 && rm -rf /var/lib/apt/lists/*

# flyctl (pinned + checksum)
RUN curl -fsSL -o /tmp/flyctl.tar.gz "https://github.com/superfly/flyctl/releases/download/v${FLYCTL_VERSION}/flyctl_${FLYCTL_VERSION}_Linux_x86_64.tar.gz" \
 && echo "${FLYCTL_SHA256}  /tmp/flyctl.tar.gz" | sha256sum -c - \
 && tar -xzf /tmp/flyctl.tar.gz -C /usr/local/bin flyctl \
 && ln -s /usr/local/bin/flyctl /usr/local/bin/fly \
 && rm /tmp/flyctl.tar.gz \
 && fly version

# gh (pinned + checksum)
RUN curl -fsSL -o /tmp/gh.tar.gz "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz" \
 && echo "${GH_SHA256}  /tmp/gh.tar.gz" | sha256sum -c - \
 && tar -xzf /tmp/gh.tar.gz -C /tmp \
 && mv "/tmp/gh_${GH_VERSION}_linux_amd64/bin/gh" /usr/local/bin/gh \
 && rm -rf /tmp/gh.tar.gz "/tmp/gh_${GH_VERSION}_linux_amd64" \
 && gh --version

# Node.js (pinned + checksum) — runtime for the Claude Code CLI
RUN curl -fsSL -o /tmp/node.tar.xz "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" \
 && echo "${NODE_SHA256}  /tmp/node.tar.xz" | sha256sum -c - \
 && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 --no-same-owner \
 && rm /tmp/node.tar.xz \
 && node --version && npm --version

# Claude Code CLI (pinned)
RUN npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
 && claude --version

# dnscontrol (pinned + checksum)
RUN curl -fsSL -o /tmp/dnscontrol.tar.gz "https://github.com/StackExchange/dnscontrol/releases/download/v${DNSCONTROL_VERSION}/dnscontrol_${DNSCONTROL_VERSION}_linux_amd64.tar.gz" \
 && echo "${DNSCONTROL_SHA256}  /tmp/dnscontrol.tar.gz" | sha256sum -c - \
 && tar -xzf /tmp/dnscontrol.tar.gz -C /usr/local/bin dnscontrol \
 && rm /tmp/dnscontrol.tar.gz \
 && dnscontrol version

# CloudCLI (pinned) — browser UI for Claude Code; the platform proxies to it
RUN npm install -g "@cloudcli-ai/cloudcli@${CLOUDCLI_VERSION}" \
 && cloudcli --version

# Superpowers plugin for Claude Code. Both commands work without a login;
# they only need git and network. Installed for root, whose HOME is the
# runtime HOME, so the absolute installPath recorded in installed_plugins.json
# stays valid.
RUN claude plugin marketplace add anthropics/claude-plugins-official \
 && claude plugin install superpowers@claude-plugins-official \
 && test -f /root/.claude/plugins/installed_plugins.json \
 && grep -q '"superpowers@claude-plugins-official"' /root/.claude/settings.json \
 && rm -f /root/.claude.json

ENV CLAUDE_CLI_PATH=/usr/local/bin/claude

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /work
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
