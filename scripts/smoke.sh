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
      if "$DOCKER" exec "$name" head -1 /work/CLAUDE.md | grep -q "contributor box"; then
        echo "smoke: contributor profile active"
      else
        echo "smoke: FAILED — wrong profile"
        exit 1
      fi

      # Mint a JWT the same way the platform does (HS256, {userId, username})
      # and confirm CloudCLI accepts it for the seeded user.
      TOKEN=$(node -e 'const c=require("crypto");const b=s=>Buffer.from(s).toString("base64url");const h=b(JSON.stringify({alg:"HS256",typ:"JWT"}));const now=Math.floor(Date.now()/1000);const p=b(JSON.stringify({userId:1,username:"box",iat:now,exp:now+3600}));const s=c.createHmac("sha256","smoke-secret").update(h+"."+p).digest("base64url");console.log(h+"."+p+"."+s)' 2>/dev/null || true)
      if [[ -z "$TOKEN" ]]; then
        TOKEN=$("$DOCKER" exec "$name" node -e 'const c=require("crypto");const b=s=>Buffer.from(s).toString("base64url");const h=b(JSON.stringify({alg:"HS256",typ:"JWT"}));const now=Math.floor(Date.now()/1000);const p=b(JSON.stringify({userId:1,username:"box",iat:now,exp:now+3600}));const s=c.createHmac("sha256","smoke-secret").update(h+"."+p).digest("base64url");console.log(h+"."+p+"."+s)')
      fi
      body=$(curl -fsS -H "Authorization: Bearer $TOKEN" http://127.0.0.1:18080/api/auth/user || true)
      if [[ "$body" == *'"username":"box"'* ]]; then
        echo "smoke: JWT contract ok"
      else
        echo "smoke: FAILED — JWT contract"
        echo "$body"
        exit 1
      fi
      exit 0
    fi
  fi
  sleep 1
done
echo "smoke: FAILED — last status: ${status:-none}"
"$DOCKER" logs "$name" | tail -40
exit 1
