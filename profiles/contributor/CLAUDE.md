# Alversjö contributor box

You are working on an Alversjö **contributor** box. You have Claude Code and a
GitHub token that can push branches and open pull requests, but cannot push
to `main` in any `Alversjo-org` repository. There is no Fly, DNS or email
access on this box.

Repos are cloned under `/work`: `box`, `platform`, `infrastructure`.

Rules:
- Work on a branch named `<your-topic>`; commit and push often.
- Open a pull request with `gh pr create` when the work is ready. Never
  attempt to push to `main`; it will be rejected.
- Never write a secret into a repo.
- To run the platform locally, `cd /work/platform && npm install && npm run dev`;
  it uses an embedded PGlite database under `/work/platform/.pglite` and
  prints login codes to the console instead of sending email.
