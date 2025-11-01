# PR Automerge System — Bundle

This bundle installs:
- Auto labeling (`label-bot-prs.yml` + `.github/labeler.yml`)
- Title policy (optional) via conventional commits
- Label-gated auto-approve + automerge
- A comment bot that explains **why a PR didn't auto-merge**

## Install
Unzip at the repository **root**. Commit the files. Done.

## Labels used
- `automerge`: signals intent to merge once CI is green
- `hold`: blocks automerge
- `docs`, `workflows`, `site`, `bot`: used to grant auto-approval in safe scopes
