#!/usr/bin/env bash
# Boot script for the Alversjö admin box. Must never crash-loop: the box has to
# stay reachable via `fly ssh console` even when a token is missing or GitHub
# is unreachable, so every failure downgrades to a logged warning.
set -u

log() { echo "[entrypoint] $*"; }

for var in FLY_API_TOKEN GH_TOKEN CLAUDE_CODE_OAUTH_TOKEN; do
  if [[ -z "${!var:-}" ]]; then
    log "WARNING: $var is not set — the corresponding CLI is unauthenticated"
  fi
done

git config --global user.name "Alversjö Admin Box"
git config --global user.email "admin-box@users.noreply.github.com"
git config --global init.defaultBranch main

if [[ -n "${GH_TOKEN:-}" ]]; then
  gh auth setup-git || log "WARNING: gh auth setup-git failed; git push over HTTPS won't work"
fi

# /work is a Fly volume: the clone survives deploys, so only clone when absent.
mkdir -p /work
if [[ ! -d /work/admin-box/.git ]]; then
  if git clone https://github.com/alversjo-org/admin-box.git /work/admin-box; then
    log "cloned alversjo-org/admin-box into /work/admin-box"
  else
    log "WARNING: could not clone alversjo-org/admin-box"
  fi
fi

log "admin box up — connect with: fly ssh console -a alversjo-admin-box"
exec sleep infinity
