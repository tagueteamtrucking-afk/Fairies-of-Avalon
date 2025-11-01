# PR Automerge Comment Bot

This workflow posts a clear comment on a Pull Request explaining **why it did not auto‑merge**.

## What it checks

- Missing `automerge` label
- Presence of `hold` label
- Draft status
- CI status (classic statuses + Checks API)
- Approvals (at least one APPROVED review if branch rules require)
- GitHub `mergeable_state` (conflicts, blocked, unknown, etc.)

## Install

1. Copy `.github/workflows/pr-automerge-comment-bot.yml` into your repo.
2. Ensure your existing auto‑merge workflow keys off the `automerge` label and requires CI green.
3. (Optional) Add `CODEOWNERS` / branch protection as you prefer.

## Permissions

The workflow uses:
- `pull-requests: write` and `issues: write` — to comment and tidy previous bot comments
- `checks: read`, `statuses: read` — to read CI state
- `contents: read` — to fetch PR details

## How it behaves

It triggers on common PR events and posts a **single consolidated** status comment with reasons.  
On each run, it removes its old comment to avoid noise.

## Uninstall

Delete `.github/workflows/pr-automerge-comment-bot.yml`.
