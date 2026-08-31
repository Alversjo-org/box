# Alversjö admin box — design

**Date:** 2026-08-31
**Status:** approved

## Purpose

A standalone admin repo + Fly machine for operating the (not yet built)
Alversjö membership platform. Deliberately independent from the platform's
future repos. Lives entirely in the `alversjo-org` GitHub org and the
`alversjo` Fly.io org. Working rule: every change is committed and pushed
immediately.

## Decisions

| Question | Decision | Why |
|---|---|---|
| Token delivery | Fly secrets → env vars | Baking tokens into the image/repo would leak them to anyone with pull access, and GitHub secret scanning would auto-revoke the PAT on push. All three CLIs natively read env vars (`FLY_API_TOKEN`, `GH_TOKEN`, `CLAUDE_CODE_OAUTH_TOKEN`), so no config files are written at all. |
| SSH access | `fly ssh console` only | Zero image setup, no public ports, gated by Fly org membership. |
| Lifecycle | Always-on, `shared-cpu-1x`/2GB, volume `work_data` at `/work` | Claude Code wants >1GB; the volume preserves clones/session state across deploys. |
| Naming | GitHub `alversjo-org/admin-box` (private), Fly app `alversjo-admin-box`, region `arn` | Short in-org name; Fly app names are global so the Fly side carries the prefix. |

## Architecture

- `Dockerfile` — `debian:bookworm-slim` pinned by digest; flyctl, gh, Node
  (all pinned + sha256-checked) and Claude Code (npm, version-pinned).
- `entrypoint.sh` — warns about missing tokens (never exits: the box must stay
  SSH-able for debugging), sets git identity, runs `gh auth setup-git`, clones
  `alversjo-org/admin-box` to `/work/admin-box` when absent, then
  `exec sleep infinity`.
- `fly.toml` — no services, no public IPs; mount + vm sizing + restart policy.

## Error handling

- Missing/invalid token → logged warning, box stays up, fix via
  `fly secrets set` (auto-restarts the machine).
- Deploy wipes rootfs → `/work` volume survives; entrypoint never overwrites
  an existing clone.

## Verification

After deploy, from the admin's machine:
`fly ssh console -a alversjo-admin-box -C "..."` for `fly orgs list`,
`gh auth status`, `claude --version`, and a `git -C /work/admin-box status`.
