# BFX Container Release Automation Workflow

This workflow automates the process of checking for new container releases for tools in the `bfx` directory, updating their `release.json` files, and creating pull requests for each update.

## Workflow Triggers
- **Scheduled:** Runs every Sunday at 8:00 AM UTC
- **Manual:** Can be triggered manually via GitHub Actions

## Main Steps
1. **Checkout Repository**
   - Uses the latest code from the repository.
2. **Install Required Tools**
   - Installs `jq` and `curl` for JSON and HTTP operations.
   - Authenticates GitHub CLI (`gh`) using the repository token.
3. **Check and Process Updates**
   - Configures git user for commits.
   - Stores the current branch name for later checkout.
   - Iterates over each tool in the `bfx` directory:
     - Checks for the latest release tag from the tool's code repository (GitHub or GitLab).
     - Checks for matching container tags on Quay.io.
     - If a new version is found and not present in `release.json`, creates a new branch, updates the file, commits, and pushes the change.
     - Creates a pull request for each update, assigning reviewers (`gkr0110`, `vipin-bc`) and labels (`automated`, `new tool version`).
     - Returns to the original branch after each PR.

## Key Features
- **Per-Tool PRs:** Each tool update is handled in its own branch and PR.
- **Automated Reviewers & Labels:** PRs automatically assign reviewers and labels for tracking.
- **Error Handling:** Skips tools without a `release.json` or if no new version is found.
- **Supports GitHub & GitLab:** Can fetch latest tags from both providers.

## Environment Variables
- `GITHUB_TOKEN`: Used for authentication with GitHub CLI and repository access.
- `BCORE_AUTH_TOKEN_PROD`: Used to fetch tool metadata from the Bundlecore API.

## Customization
- To add/remove reviewers or labels, modify the relevant lines in the workflow script under the PR creation section.
- To change the schedule, update the `cron` expression in the workflow trigger.

## Troubleshooting
- Ensure all reviewers exist and have access to the repository.
- Make sure required secrets (`GITHUB_TOKEN`, `BCORE_AUTH_TOKEN_PROD`) are set in the repository settings.
- Check workflow logs for error messages if PR creation or updates fail.
- You can also run this in locally to see if there is any new Git release for any of the tools using `scripts/tools-release-checker.sh`
---

For more details, see the workflow file: `.github/workflows/check-bfx-releases.yml`.
