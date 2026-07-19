[![Dependabot Updates](https://github.com/bundlecore/bundlecore-containers/actions/workflows/dependabot/dependabot-updates/badge.svg)](https://github.com/bundlecore/bundlecore-containers/actions/workflows/dependabot/dependabot-updates)
[![Build and Push Docker Images](https://github.com/bundlecore/bundlecore-containers/actions/workflows/ci.yml/badge.svg)](https://github.com/bundlecore/bundlecore-containers/actions/workflows/ci.yml)
[![Retag and Sign BioContainer Images](https://github.com/bundlecore/bundlecore-containers/actions/workflows/biocontainer-to-bcore-signed.yaml/badge.svg)](https://github.com/bundlecore/bundlecore-containers/actions/workflows/biocontainer-to-bcore-signed.yaml)
[![Trivy Security Scan](https://github.com/bundlecore/bundlecore-containers/actions/workflows/trivy-security-scan.yaml/badge.svg)](https://github.com/bundlecore/bundlecore-containers/actions/workflows/trivy-security-scan.yaml)

# Bundle Core Containers

This repository manages 120+ bioinformatics tools as container images. Each tool lives under `bfx/<tool>/` with a `release.json` that tracks its source images from Quay.io/BioContainers. Automated workflows retag, sign, scan, and publish all images to GitHub Container Registry (GHCR).

## Repository Structure

```
bundlecore-containers/
├── bfx/                         # 120+ bioinformatics tools
│   ├── bcftools/
│   │   ├── release.json         # Source images from Quay.io
│   │   └── trivy-scan-results.json  # Vulnerability scan results
│   ├── samtools/
│   └── ...
├── scripts/
│   └── tools-folder.sh          # Bulk tool onboarding script
├── .github/workflows/           # CI/CD automation
│   ├── onboard-new-tools.yaml             # Auto-detect new tools every 4h
│   ├── biocontainer-to-bcore-signed.yaml  # Retag & sign
│   ├── trivy-security-scan.yaml           # Vulnerability scanning
│   ├── create-release-json.yml            # Populate release.json
│   ├── check-bfx-releases.yml            # Weekly version check
│   ├── auto-merge-tool-versions.yml       # Auto-merge "new tool version" PRs
│   ├── generate-lua-files.yml             # Lua module generation
│   ├── ci.yml                             # Build & push
│   ├── auto-merge.yml                     # Dependabot auto-merge
│   └── discord.yml                        # Discord notifications
├── docs/                        # Documentation
└── README.md
```

## Workflow Chain

When a new tool is onboarded or updated, the following automated chain runs:

```
Onboard New Tools ──> Push release.json ──> create-release-json  ──> Retag & Sign  ──> Trivy Scan  ──> PR with results
(cron every 4h,       (empty file)         (populate from API)      (pull, retag,     (scan images,   (vulnerability
 creates stub folder)                                               push to GHCR,    count vulns)     summary table)
                                                                     cosign sign)
```

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| **Onboard New Tools** | Every 4 hours, or manual | Detects tool slugs in the BundleCore API not yet in `bfx/`, creates stub folders with empty `release.json`, opens a PR |
| **Generate release.json** | Push to `bfx/*/release.json` or manual | Populates empty release.json files from BundleCore API |
| **Retag and Sign** | Push to `bfx/*/release.json` or manual | Pulls images from Quay.io, retags to GHCR, signs with Cosign |
| **Trivy Security Scan** | After retag completes, monthly cron, or manual | Scans GHCR images for CRITICAL/HIGH vulnerabilities |
| **Check BFX Releases** | Weekly (Sundays 8 AM UTC) or manual | Checks Quay.io/GitHub/GitLab for new tool versions |
| **Auto-merge Tool Version PRs** | PR opened/labeled/synced, or manual | Auto-merges "new tool version" PRs that touch exactly one `bfx/<tool>/release.json` file |
| **Generate Lua Files** | Manual | Generates Lua module files for each tool version |
| **Discord Bridge** | Push, PR, issues, releases | Sends GitHub event notifications to Discord |
| **Dependabot auto-approve** | Dependabot PRs | Auto-merges Dependabot dependency updates |
| **Build and Push** | CI triggers | Builds and pushes Docker images |

## Onboarding Tools

> **Note:** The **Onboard New Tools** workflow already runs automatically every 4 hours, polling the
> BundleCore API for tool slugs that don't yet have a `bfx/` folder and opening a PR with stub
> `release.json` files. The steps below are only needed for onboarding a tool immediately or in bulk
> without waiting for the next scheduled run.

### Single Tool

1. Create the tool directory and an empty `release.json`:
   ```bash
   mkdir -p bfx/my-new-tool
   touch bfx/my-new-tool/release.json
   ```
2. Commit and push to `main`
3. The **Generate release.json** workflow auto-triggers, populates the file from the BundleCore API, and opens a PR
4. Merge the PR -> **Retag and Sign** pulls and retags images to GHCR -> **Trivy Scan** checks for vulnerabilities

### Bulk Onboarding (50+ tools)

For onboarding many tools at once (e.g., 50 tools in a batch):

1. **Set the `BCORE_AUTH_TOKEN` environment variable:**
   ```bash
   export BCORE_AUTH_TOKEN="your-bundlecore-api-token"
   ```

2. **Run the onboarding script** to create folders for all tools registered in BundleCore:
   ```bash
   bash scripts/tools-folder.sh
   ```
   This fetches the full tool list from the BundleCore API and creates `bfx/<tool>/release.json` (empty) for each tool that doesn't already have a folder.

3. **Commit and push:**
   ```bash
   git add bfx/
   git commit -m "Onboard N new tools"
   git push origin main
   ```

4. **Automated chain kicks in:**
   - **Generate release.json** triggers on the push, detects the empty `release.json` files, calls the BundleCore API to populate them, and opens a PR
   - Merge the PR
   - **Retag and Sign** triggers, processes all new tools (pulls from Quay.io, retags to GHCR, signs with Cosign)
   - **Trivy Security Scan** triggers after retag completes, scans only the newly added tools, and opens a PR with per-tool vulnerability counts

> **Note:** The workflows are designed to handle batches efficiently. The retag workflow processes tools sequentially to manage disk usage (cleaning up Docker images after each tool). A batch of 50 tools typically takes ~30-45 minutes for retag and ~15-20 minutes for Trivy scanning.

### release.json Format

Each tool's `release.json` contains the source images from Quay.io/BioContainers:

```json
{
  "images": [
    "quay.io/biocontainers/bcftools:1.21--h8b25389_0",
    "quay.io/biocontainers/bcftools:1.19--h8b25389_0"
  ]
}
```

The retag workflow derives the GHCR URL from each image: `ghcr.io/bundlecore/products/bfx/<tool>:<version>`.

## Security Scanning

Automated vulnerability scanning with [Trivy](https://trivy.dev/) runs in three scenarios:

| Trigger | Scope | Typical Duration |
|---------|-------|-----------------|
| After retag completes | Only the tools that changed | 5-15 min |
| Monthly cron (1st of the month, 2 AM UTC) | All tools | ~40 min |
| Manual dispatch (`scan_mode=all` or `changed-only`) | Configurable | Varies |

### How It Works

1. **detect-scope** - Determines which tools to scan based on the trigger
2. **scan** - For each target tool: discovers GHCR images, runs Trivy, writes organized results to `bfx/<tool>/trivy-scan-results.json`
3. **create-pr** - Commits scan results and opens a PR with a per-tool vulnerability summary table (skipped if zero vulnerabilities)

### Quick Start

```bash
# Scan all tools
gh workflow run "Trivy Security Scan" -f scan_mode=all

# Scan only recently changed tools
gh workflow run "Trivy Security Scan" -f scan_mode=changed-only
```

### Security Review Process

1. Review the PR created by Trivy scan - it includes a summary table with CRITICAL and HIGH counts per tool
2. Check `bfx/<tool>/trivy-scan-results.json` for detailed vulnerability information
3. Prioritise CRITICAL vulnerabilities for immediate remediation
4. Merge the PR to update the vulnerability baseline

## Version Tracking

The **Check BFX Container Releases** workflow runs weekly and:

1. Checks each tool's latest version from GitHub/GitLab releases and Quay.io tags
2. If a new version is found, updates the tool's `release.json` and opens a PR
3. Updates the BundleCore API with the new version information
4. The **Auto-merge Tool Version PRs** workflow merges the PR automatically as long as it only
   touches a single `bfx/<tool>/release.json` file, which triggers the retag -> sign -> scan chain.
   PRs that touch anything else are left for manual review.

## Using Container Images

All container images are available from GitHub Container Registry:

```bash
# Pull a specific tool
docker pull ghcr.io/bundlecore/products/bfx/bcftools:1.21

# List available images
gh api /orgs/bundlecore/packages?package_type=container
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Ensure all CI checks pass
5. Submit a pull request

## License

This project is licensed under the [MIT License](LICENSE).
