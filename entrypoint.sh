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

# Profile selection. Unknown values fall back to the least privileged profile.
case "${BOX_PROFILE:-}" in
  admin|contributor) ;;
  "") log "WARNING: BOX_PROFILE is not set — defaulting to contributor"; BOX_PROFILE=contributor ;;
  *)  log "WARNING: unknown BOX_PROFILE '${BOX_PROFILE}' — defaulting to contributor"; BOX_PROFILE=contributor ;;
esac
export BOX_PROFILE
mkdir -p /work
cp "/opt/box/profiles/${BOX_PROFILE}/CLAUDE.md" /work/CLAUDE.md
log "profile: ${BOX_PROFILE}"

git config --global user.name "Alversjö Box (${BOX_PROFILE})"
git config --global user.email "box-${BOX_PROFILE}@users.noreply.github.com"
git config --global init.defaultBranch main

if [[ -n "${GH_TOKEN:-}" ]]; then
  gh auth setup-git || log "WARNING: gh auth setup-git failed; git push over HTTPS won't work"
fi

# Interactive `claude` gates its first-run login wizard on this flag, not on
# whether CLAUDE_CODE_OAUTH_TOKEN is set; seed it so SSH sessions get a REPL
# straight away. /root is rebuilt from the image on every deploy, hence here.
if [[ ! -f /root/.claude.json ]]; then
  echo '{"hasCompletedOnboarding": true}' > /root/.claude.json
fi
mkdir -p /root/.claude
if [[ ! -f /root/.claude/settings.json ]]; then
  echo '{"theme": "dark"}' > /root/.claude/settings.json
fi

# /work is a Fly volume: the clone survives deploys, so only clone when absent.
mkdir -p /work
if [[ ! -d /work/box/.git ]]; then
  if git clone https://github.com/Alversjo-org/box.git /work/box; then
    log "cloned Alversjo-org/box into /work/box"
  else
    log "WARNING: could not clone Alversjo-org/box"
  fi
fi

log "box up — fallback shell: fly ssh console -a alversjo-boxes -s"
exec sleep infinity
