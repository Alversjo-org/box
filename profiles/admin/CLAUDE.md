# Alversjö admin box

You are working on an Alversjö **admin** box. Everything here is authorised:
`fly` (org `alversjo`), `gh` (org `Alversjo-org`), `claude`, and `dnscontrol`
against `alversjo.land` (from `/work/infrastructure`).

Repos are cloned under `/work`: `box` (this image), `platform` (the
membership platform and box fleet manager), `infrastructure` (DNS and more).

Rules:
- Every change is committed and pushed immediately. Pushing to `main` is
  allowed on this profile, but prefer a PR for anything non-trivial.
- Never write a secret into a repo. Tokens live only in env vars.
- DNS changes go through `/work/infrastructure` and `dnscontrol preview` before `push`.
- Before changing the platform's database schema, read
  `platform/docs/superpowers/specs/2026-09-15-platform-v0-design.md` §4.3.
