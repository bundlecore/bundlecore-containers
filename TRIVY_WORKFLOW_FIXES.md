# Trivy Security Scan Workflow Fixes

## Problem
The Trivy security scan workflow was failing with exit code 1 during the image discovery phase. The error occurred when trying to fetch container packages from the GitHub API.

## Root Cause Analysis
After examining both workflows, I discovered there are actually TWO different workflows that publish containers:

1. **CI Workflow** (`ci.yml`): Publishes containers as `ghcr.io/bundlecore/bundlecore-containers/{app}:{tag}`
2. **Biocontainer Workflow** (`biocontainer-to-bcore-signed.yaml`): Publishes containers as `ghcr.io/bundlecore/products/bfx/{tool}:{tag}`

The Trivy workflow was correctly looking for the `products/bfx/` pattern, which matches the biocontainer workflow that processes the `bfx/` directory.

## Issues Fixed

### 1. API Endpoint Fallback
- **Before**: Only trying organization endpoint: `/orgs/{org}/packages`
- **After**: Try organization endpoint first, then user endpoint: `/users/{user}/packages`

### 2. Enhanced Error Handling
- Added better fallback logic for API calls
- Improved error messages and troubleshooting guidance

### 3. Maintained Correct Package Filtering
- **Confirmed**: Looking for packages matching `products/bfx/*` pattern is correct
- This matches the biocontainer workflow that processes tools from the `bfx/` directory

## Expected Image Format
Based on the biocontainer workflow analysis, container images are published as:
```
ghcr.io/bundlecore/products/bfx/{tool}:{tag}
```

Example: `ghcr.io/bundlecore/products/bfx/bedtools:2.30.0--h468198e_3`

Where:
- `bundlecore` = GitHub organization
- `products/bfx` = Product domain from biocontainer workflow
- `{tool}` = Tool name (e.g., bedtools, samtools, etc.)
- `{tag}` = Version tag

## Workflow Context
The repository has two container publishing workflows:

1. **CI Workflow**: Builds containers from `containers/` directory
2. **Biocontainer Workflow**: Retags and signs biocontainer images from `bfx/` directory

The Trivy security scan is designed to scan the biocontainer images (products/bfx/*), which is the correct approach.

## Testing
1. Created `test-api-access.sh` script to help debug API access issues
2. Verified workflow syntax with no errors
3. Maintained correct validation patterns for products/bfx/* format

## Next Steps
1. Run the workflow to test the fixes
2. If still failing, use the test script to debug API access
3. Verify that biocontainer packages exist and are accessible with the current GITHUB_TOKEN permissions