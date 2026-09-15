# Alversjö box image

This repo builds the Docker image that every Alversjö "box" runs: the
protected admin box and every dev box the platform creates. It is deployed
as machines in the Fly app `alversjo-boxes` (org `alversjo`, region `arn`) by
the platform (`Alversjo-org/platform`), never by `fly deploy` from here.

## Non-negotiable rule

**Every change to this repo is committed and pushed to GitHub immediately.**
No local-only state, no long-lived branches. This applies to the local clone
and to the clone on any box (`/work/box`).

## How auth works

No credentials exist in this repo or in the image. Everything arrives as
machine env vars set by the platform at creation time:

| Env | admin | contributor | Used by |
|---|---|---|---|
| `CLAUDE_CODE_OAUTH_TOKEN` | yes | yes | `claude` |
| `GH_TOKEN` | full org token | bot account token | `gh`, git over HTTPS |
| `FLY_API_TOKEN` | yes | no | `fly` |
| `RESEND_API_KEY` | yes | no | running the platform locally |
| `CLOUDFLARE_API_TOKEN` | yes | no | `dnscontrol` in `/work/infrastructure` |
| `JWT_SECRET` | yes | yes | CloudCLI, minted per box by the platform |
| `BOX_PROFILE` | `admin` | `contributor` | entrypoint profile selection |

## Image tags

CI pushes two tags to `registry.fly.io/alversjo-boxes` on every push to
`main`: `<git-sha>` and `latest`. `latest` is mutable — Fly pins a machine to
the image digest at creation time, so an existing machine never moves when
`latest` is repointed. Pass `registry.fly.io/alversjo-boxes:<sha>` when
creating a machine if you need a reproducible box.

## Network

CloudCLI binds `HOST="::"` (all interfaces) deliberately, so the image can be
smoke-tested locally (`scripts/smoke.sh` publishes port 8080 to the host).
Boxes stay private only because the `alversjo-boxes` Fly app's machine config
has `services: []` — there is no public service on the app. Never add a
`services` entry to `alversjo-boxes`; if one is ever needed, put CloudCLI
behind auth first.

## Layout on a box

- `/work` is the persistent volume. Repos are cloned there on first boot:
  `/work/box`, `/work/platform`, `/work/infrastructure`.
- `/work/CLAUDE.md` is copied from `profiles/<BOX_PROFILE>/CLAUDE.md` on every boot.
- CloudCLI runs on port 8080 with its database at `/work/.cloudcli/auth.db`.
  The platform proxies to it; there is no public port.
- `fly ssh console -a alversjo-boxes -s` still works as a fallback for admins.

## Building

CI builds and pushes on every push to `main`. Locally:

    docker build -t box .
    scripts/smoke.sh box     # boots the image with fake tokens and checks CloudCLI answers
