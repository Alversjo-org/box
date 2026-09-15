#!/usr/bin/env bash
# Boots the image with fake tokens and checks that CloudCLI comes up with the
# seeded user. Usage: scripts/smoke.sh <image>
set -euo pipefail
image="${1:?image}"
name="box-smoke-$$"
DOCKER="${DOCKER:-docker}"
cleanup() { "$DOCKER" rm -f "$name" >/dev/null 2>&1 || true; }
trap cleanup EXIT

"$DOCKER" run -d --name "$name" -p 127.0.0.1:18080:8080 \
  -e BOX_PROFILE=contributor -e JWT_SECRET=smoke-secret \
  -e CLAUDE_CODE_OAUTH_TOKEN=fake -e GH_TOKEN=fake \
  "$image" >/dev/null

for _ in $(seq 1 90); do
  if status=$(curl -fsS http://127.0.0.1:18080/api/auth/status 2>/dev/null); then
    if [[ "$status" == *'"needsSetup":false'* ]]; then
      echo "smoke: CloudCLI up, user seeded"
      "$DOCKER" exec "$name" head -1 /work/CLAUDE.md | grep -q "contributor box" && echo "smoke: contributor profile active"
      exit 0
    fi
  fi
  sleep 1
done
echo "smoke: FAILED — last status: ${status:-none}"
"$DOCKER" logs "$name" | tail -40
exit 1
