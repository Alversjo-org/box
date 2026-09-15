# box

The Docker image behind every Alversjö box: a small Debian image with
`fly`, `gh`, `claude`, `dnscontrol` and a
[CloudCLI](https://github.com/siteboon/claudecodeui) server. Every CLI
authenticates from env vars at runtime (set by the platform when it creates
the box), so people can work with Claude Code in the browser through the
Alversjö platform.

Two profiles, chosen by `BOX_PROFILE`:

- **admin**: every token, can push to `main`, can manage Fly and DNS.
- **contributor**: Claude plus a bot GitHub token that can only open pull
  requests. Meant for members developing a feature.

Boxes are created and reached through `Alversjo-org/platform`. This repo only
builds the image; CI pushes it to `registry.fly.io/alversjo-boxes`.

**Rule of the repo: every change is committed and pushed immediately.** See
[CLAUDE.md](CLAUDE.md).

## Troubleshooting `fly ssh console`

`tunnel unavailable: Error contacting Fly.io API when probing "alversjo"` is a
known flyctl limitation (issue
[#3306](https://github.com/superfly/flyctl/issues/3306)): Fly evicts idle
WireGuard peers, and the first command after ~25 minutes can time out before
the agent reconnects. Wait 30–60 s and retry. `fly wireguard reset` and
`fly wireguard websockets enable` help on flaky networks.
