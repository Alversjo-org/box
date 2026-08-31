# Alversjö admin box

This repo defines the admin workstation for operating the Alversjö membership
platform (which lives in separate repos in the `alversjo-org` GitHub org — this
repo is deliberately independent from it). It builds a Docker image containing
pre-authenticated `fly`, `gh`, and `claude` CLIs and deploys it as one
always-on Fly machine (`alversjo-admin-box`, Fly org `alversjo`, region `arn`).

## Non-negotiable rule

**Every change to this repo is committed and pushed to GitHub immediately.**
No local-only state, no long-lived branches, no "I'll push later". This applies
both to the local clone and to the clone on the box itself (`/work/admin-box`).

## How auth works

No credentials exist in this repo or in the image. The three CLIs read their
tokens from environment variables, injected as Fly secrets:

| Secret | Auths |
|---|---|
| `FLY_API_TOKEN` | `fly` (org-scoped deploy token for `alversjo`) |
| `GH_TOKEN` | `gh` + git-over-HTTPS (via `gh auth setup-git` in the entrypoint) |
| `CLAUDE_CODE_OAUTH_TOKEN` | `claude` |

Rotate with `fly secrets set NAME=... -a alversjo-admin-box` (restarts the machine).

## Quick reference

```bash
fly deploy --ha=false                      # build (remote builder) + deploy
fly ssh console -a alversjo-admin-box      # shell into the box
fly logs -a alversjo-admin-box             # entrypoint logs
```

On the box, `/work` is a persistent volume; the working clone of this repo is
at `/work/admin-box`. Everything outside `/work` is wiped on each deploy.
