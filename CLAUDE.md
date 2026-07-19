# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`bundlecore-containers` is a **data/config repository**, not an application. It tracks source container
images for 260+ bioinformatics tools (under `bfx/`) and drives a chain of GitHub Actions workflows that
retag those images to GHCR, sign them, scan them for vulnerabilities, and generate Lmod/Lua module files.
There is no application code to build or run — most "development" here is editing JSON files and bash-based
GitHub Actions workflows.

There is also a small, older `containers/` directory (`augusta`, `miit`, `rmats-turbo`) holding hand-written
Dockerfiles built from source via `.github/workflows/ci.yml`. This is a legacy path — new tools always go
through `bfx/`, not `containers/`.

## Core model: `bfx/<tool>/`

Each tool directory contains:
- `release.json` — the only hand-relevant file. Lists source images pulled from Quay.io/BioContainers:
  ```json
  { "images": ["quay.io/biocontainers/bcftools:1.24--h487d631_0", "..."] }
  ```
  An **empty** `release.json` (0 bytes) marks a tool as not-yet-onboarded/not-yet-populated — several
  workflows key off `[ -s release.json ]` to detect this state.
- `trivy-scan-results.json` — generated vulnerability scan output, one entry per version under `.versions`.
- `<version>.lua` — generated Lmod module files (one per image tag).

**Version tag derivation** (used consistently across workflows): given an image tag like
`1.21--h3a4d415_1`, the GHCR tag is everything before the first `--` (`1.21`). The GHCR image path is
always `ghcr.io/<org>/products/bfx/<tool-slug>:<short-tag>`.

## The automation chain

```
Onboard New Tools (cron/4h)  → creates empty bfx/<tool>/release.json, opens PR
        ↓ merge
Generate release.json (on push to bfx/*/release.json)
        → calls BundleCore API, populates release.json with source images, opens PR
        ↓ merge
Retag and Sign (on push to bfx/*/release.json)
        → pulls each Quay.io image, retags to GHCR, cosign-signs, pushes,
          updates the BundleCore API's tool-version record
        ↓ triggers on completion
Trivy Security Scan (workflow_run after Retag and Sign, or monthly cron, or manual)
        → scans GHCR images (CRITICAL/HIGH only), writes bfx/<tool>/trivy-scan-results.json,
          opens a PR with a per-tool vuln summary table (skipped if zero vulns)

Check BFX Container Releases (weekly, Sundays 8am UTC)
        → polls each tool's GitHub/GitLab releases + Quay.io tags for newer versions,
          prepends new images to release.json, opens a PR labeled "new tool version"
        ↓ triggers on PR opened/labeled/synchronize
Auto-merge Tool Version PRs
        → auto-merges the PR iff: author is github-actions[bot], labeled "new tool version",
          and it touches exactly one bfx/<tool>/release.json file. Anything else is left for
          manual review. (This re-triggers the retag→scan chain above.)

Generate Lua Files (manual dispatch only)
        → scripts/luagen.py renders scripts/template_file.lua per (tool, version) into bfx/<tool>/<version>.lua
```

Key workflow files, all in `.github/workflows/`:
| File | Purpose |
|---|---|
| `onboard-new-tools.yaml` | Detects new tool slugs from the BundleCore API not yet in `bfx/`, creates stub folders |
| `create-release-json.yml` | Populates empty `release.json` files from the BundleCore API |
| `biocontainer-to-bcore-signed.yaml` | Retag Quay.io images → GHCR, cosign sign, update BundleCore |
| `trivy-security-scan.yaml` | Three-job pipeline: `detect-scope` → `scan` → `create-pr` |
| `check-bfx-releases.yml` | Weekly check for newer upstream tool versions |
| `auto-merge-tool-versions.yml` | Auto-merges "new tool version" PRs that touch a single `release.json` |
| `generate-lua-files.yml` | Regenerates `.lua` module files via `scripts/luagen.py` |
| `ci.yml` | Legacy build-from-source pipeline for `containers/*` only |
| `auto-merge.yml` | Auto-merges Dependabot PRs |
| `discord.yml` | Bridges GitHub events to Discord |

Almost every automated PR is opened against `main` with reviewers `gkr0110` and `vipin-bc` added
best-effort via `gh pr edit`.

## External dependencies

- **BundleCore API** (`https://bundlecore.com/api/...`) is the source of truth for the tool registry
  (slugs, versions, `registryUrl`/`bcRegistryUrl`). Auth via `BCORE_AUTH_TOKEN` / `BCORE_AUTH_TOKEN_PROD`
  secret. Workflows both read from it (tool list, version metadata) and write to it (new versions,
  registry URLs) — keep both directions in sync when touching this logic.
- **Quay.io** is the upstream source registry for BioContainer images; **GHCR**
  (`ghcr.io/bundlecore/products/bfx/<tool>`) is the destination, signed with Cosign.
- **Trivy** (`aquasec/trivy`, pinned image tag) scans for CRITICAL/HIGH vulnerabilities only.

## Scripts (`scripts/`)

- `tools-folder.sh` — bulk-create empty `bfx/<tool>/release.json` stubs for every tool slug the BundleCore
  API knows about (manual bulk-onboarding path; requires `BCORE_AUTH_TOKEN` env var).
- `luagen.py` — `python scripts/luagen.py <tool_name> <tool_version> <tool_domain>`; fetches tool metadata
  from the BundleCore API and fills `template_file.lua`. Requires `requests` (see `requirements.txt`) and
  `BCORE_AUTH_TOKEN`.
- `tools-release-checker.sh`, `backfill-bc-registry-urls.sh`, `test-api-access.sh`,
  `test-large-response.sh` — one-off/maintenance helpers for the same API and registry data.

## Tests

`tests/trivy-security-scan/` contains bash-based unit/integration tests for the Trivy scan workflow logic.
Run with:
```bash
bash tests/trivy-security-scan/scripts/run-tests.sh [unit|integration|all] [-v] [-p] [-c]
```
Requires `jq`. Note some referenced test files (e.g. `integration/test-workflow-execution.sh`) may not
exist yet — the runner will report them as missing rather than failing silently.

## Working in this repo

- When adding or modifying a tool, the only file a human typically edits by hand is `bfx/<tool>/release.json`
  (or creating the empty stub) — everything else (`*.lua`, `trivy-scan-results.json`) is workflow-generated.
  Don't hand-edit generated files; change the workflow/script instead if the output is wrong.
- Workflow bash scripts favor `jq` for all JSON manipulation and rewrite files via a `*.tmp` + `mv` pattern —
  follow that convention rather than in-place `sed` on JSON.
- Path-triggered workflows key off changes under `bfx/*/release.json` specifically — if restructuring paths,
  update the `paths:` filters and any `git diff --name-only` parsing in the affected workflow(s) together.
