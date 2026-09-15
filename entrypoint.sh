#!/usr/bin/env bash
# Boot script for the Alversjö box. Must never crash-loop: the box has to
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

# Claude Code keeps per-project session data and todos under /root/.claude,
# but /root is rebuilt from the image on every image update. Persist that
# state on the volume and symlink it back so it survives updates. Leaves
# /root/.claude/plugins and settings.json alone.
mkdir -p /work/.claude/projects /work/.claude/todos
for name in projects todos; do
  src="/root/.claude/${name}"
  dst="/work/.claude/${name}"
  if [[ -e "$src" && ! -L "$src" ]]; then
    (shopt -s dotglob nullglob; mv "$src"/* "$dst"/ 2>/dev/null) || true
    rm -rf "$src" 2>/dev/null || log "WARNING: could not remove /root/.claude/${name}"
  fi
  ln -sfn "$dst" "$src" 2>/dev/null || log "WARNING: could not symlink /root/.claude/${name} to the volume"
done

# /work is a Fly volume: clones survive restarts, so only clone when absent.
# Repos are public, so cloning needs no token; pushing does (gh auth setup-git).
for repo in box platform infrastructure; do
  if [[ ! -d "/work/${repo}/.git" ]]; then
    if [[ -d "/work/${repo}" ]]; then
      log "removing partial clone at /work/${repo}"
      rm -rf "/work/${repo}"
    fi
    if timeout 300 git clone "https://github.com/Alversjo-org/${repo}.git" "/work/${repo}"; then
      log "cloned Alversjo-org/${repo} into /work/${repo}"
    else
      log "WARNING: could not clone Alversjo-org/${repo}"
    fi
  fi
done

# CloudCLI: browser UI the platform proxies to. Port 8080, no public service.
# JWT mode with a single seeded user; the platform mints tokens with JWT_SECRET.
export HOST="::"
export SERVER_PORT=8080
export DATABASE_PATH=/work/.cloudcli/auth.db
export WORKSPACES_ROOT=/work
export CLAUDE_CLI_PATH=/usr/local/bin/claude
mkdir -p /work/.cloudcli
if [[ -z "${JWT_SECRET:-}" ]]; then
  log "WARNING: JWT_SECRET is not set — CloudCLI will generate its own and the platform cannot log in"
fi

seed_cloudcli_user() {
  # Wait for the server, then register the single user if the DB is empty.
  local status
  for _ in $(seq 1 60); do
    status=$(curl -fsS http://localhost:8080/api/auth/status 2>/dev/null || true)
    [[ -n "$status" ]] && break
    sleep 1
  done
  if [[ "$status" == *'"needsSetup":true'* ]]; then
    local password attempt
    password=$(head -c 24 /dev/urandom | base64 | tr -d '\n=/+')
    for attempt in 1 2 3; do
      if curl -fsS -X POST -H 'content-type: application/json' \
           -d "{\"username\":\"box\",\"password\":\"${password}\"}" \
           http://localhost:8080/api/auth/register >/dev/null; then
        log "seeded CloudCLI user 'box'"
        return
      fi
      sleep 5
    done
    log "WARNING: could not seed CloudCLI user"
  fi
}

seed_cloudcli_project() {
  # Once CloudCLI has finished setup, register /work as a project so opening
  # a box shows a ready workspace instead of "No projects found". Idempotent:
  # skips if /work is already registered. Projects live in CloudCLI's own DB
  # on the volume, so this only does real work on a fresh volume.
  local status
  for _ in $(seq 1 60); do
    status=$(curl -fsS http://localhost:8080/api/auth/status 2>/dev/null || true)
    [[ "$status" == *'"needsSetup":false'* ]] && break
    sleep 1
  done
  if [[ "$status" != *'"needsSetup":false'* ]]; then
    log "WARNING: CloudCLI never finished setup — skipping project seed"
    return
  fi
  if [[ -z "${JWT_SECRET:-}" ]]; then
    log "WARNING: JWT_SECRET is not set — cannot seed CloudCLI project"
    return
  fi

  local token attempt projects
  token=$(JWT_SECRET="$JWT_SECRET" node -e '
    const c = require("crypto");
    const b = s => Buffer.from(s).toString("base64url");
    const h = b(JSON.stringify({ alg: "HS256", typ: "JWT" }));
    const now = Math.floor(Date.now() / 1000);
    const p = b(JSON.stringify({ userId: 1, username: "box", iat: now, exp: now + 3600 }));
    const s = c.createHmac("sha256", process.env.JWT_SECRET).update(h + "." + p).digest("base64url");
    console.log(h + "." + p + "." + s);
  ' 2>/dev/null || true)
  if [[ -z "$token" ]]; then
    log "WARNING: could not mint a JWT to seed the CloudCLI project"
    return
  fi

  for attempt in 1 2 3; do
    projects=$(curl -fsS -H "Authorization: Bearer ${token}" http://localhost:8080/api/projects 2>/dev/null || true)
    if [[ -n "$projects" ]]; then
      if [[ "$projects" == *'"path":"/work"'* ]]; then
        log "CloudCLI project /work already registered"
        return
      fi
      if curl -fsS -X POST -H 'content-type: application/json' -H "Authorization: Bearer ${token}" \
           -d '{"path":"/work","name":"Alversjö"}' \
           http://localhost:8080/api/projects/create-project >/dev/null; then
        log "seeded CloudCLI project /work"
        return
      fi
    fi
    sleep 5
  done
  log "WARNING: could not seed CloudCLI project /work"
}

log "box up (profile ${BOX_PROFILE}) — fallback shell: fly ssh console -a alversjo-boxes -s"
cloudcli_pid=0
trap 'log "signal received — stopping cloudcli"; kill -TERM "$cloudcli_pid" 2>/dev/null; wait "$cloudcli_pid" 2>/dev/null; exit 0' TERM INT
while true; do
  ( seed_cloudcli_user; seed_cloudcli_project ) &
  cloudcli start --port 8080 --database-path /work/.cloudcli/auth.db &
  cloudcli_pid=$!
  wait "$cloudcli_pid"
  rc=$?
  log "WARNING: cloudcli exited with $rc — restarting in 5s"
  sleep 5
done
