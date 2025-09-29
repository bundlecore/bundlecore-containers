# GitHub CLI Migration for Trivy Security Scan

## Problem
The GitHub Action was failing at the "Discover container images" step with exit code 1. The workflow was using direct `curl` API calls which can be unreliable due to authentication and rate limiting issues.

## Solution
Migrated from direct `curl` API calls to GitHub CLI (`gh`) for more reliable GitHub API interactions.

## Changes Made

### 1. Workflow Updates (`.github/workflows/trivy-security-scan.yaml`)

#### Added GitHub CLI Setup Step
```yaml
- name: Setup GitHub CLI
  run: |
      # Verify installation and authenticate
      gh --version
      
      # Test authentication
      if gh auth status; then
        echo "✓ GitHub CLI authenticated successfully"
      else
        echo "✗ GitHub CLI authentication failed"
        exit 1
      fi
      
      # Test basic API access
      if gh api "/orgs/$GITHUB_REPOSITORY_OWNER" >/dev/null 2>&1; then
        echo "✓ Organization API access successful"
      else
        echo "⚠ Organization API access failed"
      fi
  env:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

#### Replaced API Function
- **Before**: `make_api_call()` using `curl` with manual HTTP handling
- **After**: `make_gh_api_call()` using `gh api` with built-in authentication

#### Updated API Calls
- **Before**: `curl -H "Authorization: Bearer $TOKEN" https://api.github.com/orgs/.../packages`
- **After**: `gh api "/orgs/.../packages?package_type=container&per_page=100"`

### 2. Test Updates

#### New Test File
Created `tests/trivy-security-scan/unit/test-github-cli-integration.sh` to test:
- GitHub CLI availability and version
- Authentication status
- API calls for packages and versions
- Error handling for invalid endpoints
- Complete workflow simulation

#### Updated Existing Tests
- Removed `curl` dependency from test requirements
- Updated image discovery tests to use mock `gh` commands
- Added GitHub CLI mocking capabilities

### 3. Benefits of GitHub CLI Approach

#### Reliability
- Built-in authentication handling
- Automatic token management
- Better error messages and debugging

#### Rate Limiting
- Automatic rate limit handling
- Built-in retry logic
- Proper backoff strategies

#### Maintenance
- Simpler API calls without manual HTTP handling
- Consistent with GitHub's recommended practices
- Better integration with GitHub Actions environment

#### Security
- No need to manually handle authentication headers
- Automatic token scoping
- Built-in security best practices

## Testing the Changes

### Run Unit Tests
```bash
./tests/trivy-security-scan/scripts/run-tests.sh unit
```

### Test GitHub CLI Integration Specifically
```bash
./tests/trivy-security-scan/unit/test-github-cli-integration.sh
```

### Validate SARIF Output
```bash
./tests/trivy-security-scan/scripts/validate-sarif.sh results.sarif
```

## Expected Improvements

1. **Reduced Authentication Errors**: GitHub CLI handles token authentication automatically
2. **Better Rate Limit Handling**: Built-in retry logic and backoff strategies
3. **Improved Error Messages**: More descriptive error messages for troubleshooting
4. **Simplified Maintenance**: Less complex API handling code
5. **Better GitHub Actions Integration**: Native support for GitHub Actions environment

## Troubleshooting

If the workflow still fails:

1. **Check Token Permissions**: Ensure `GITHUB_TOKEN` has `packages:read` permission
2. **Verify Organization Access**: Check if the workflow can access the organization's packages
3. **Review Package Naming**: Ensure packages follow the `products/bfx/*` naming convention
4. **Check Package Visibility**: Verify packages are accessible to the workflow

## Migration Verification

The migration maintains backward compatibility while improving reliability:
- Same input/output format
- Same error handling behavior
- Same package discovery logic
- Enhanced debugging and logging