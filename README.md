# admin-box

The admin workstation for the Alversjö membership platform: one always-on
[Fly.io](https://fly.io) machine in the **alversjo** org running a small Debian
image with three pre-authenticated CLIs —

- **`fly`** (flyctl) — operate everything in the Alversjö Fly org
- **`gh`** — operate everything in the `alversjo-org` GitHub org, plus
  git-over-HTTPS push/pull
- **`claude`** — Claude Code, for doing admin work with an agent from inside
  the box

The membership platform itself does not exist yet and will live in separate
repos; this box is the independent place it will be administered from.

## Using it

```bash
fly ssh console -a alversjo-admin-box
```

That's the only way in: the app exposes no services and no public IPs; access
is gated by membership in the Alversjö Fly org. Inside, `/work` is a 10GB
persistent volume with this repo cloned at `/work/admin-box`.

## Deploying changes

```bash
fly deploy --ha=false
```

Fly's remote builder builds the image (no local Docker needed) and replaces
the machine. `/work` survives; the rest of the filesystem is rebuilt from the
image.

**Rule of the repo: every change is committed and pushed immediately.** See
[CLAUDE.md](CLAUDE.md).

## Secrets

Tokens are Fly secrets (`FLY_API_TOKEN`, `GH_TOKEN`, `CLAUDE_CODE_OAUTH_TOKEN`),
injected as environment variables that the CLIs read natively. Nothing secret
is in this repo or baked into the image. To rotate one:

```bash
fly secrets set GH_TOKEN=github_pat_... -a alversjo-admin-box
```

## First-time bootstrap (already done, recorded for posterity)

```bash
gh repo create alversjo-org/admin-box --private
fly apps create alversjo-admin-box --org alversjo
fly volumes create work_data -a alversjo-admin-box -r arn -s 10 -y
fly secrets set -a alversjo-admin-box FLY_API_TOKEN=... GH_TOKEN=... CLAUDE_CODE_OAUTH_TOKEN=...
fly deploy --ha=false
```
