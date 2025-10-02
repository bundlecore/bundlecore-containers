# Debug Improvements for Trivy Workflow

## Problem
The Trivy workflow is still failing with exit code 1, suggesting a `packages:read` permission issue.

## Debug Enhancements Added

### 1. Environment Debug Information
Added detailed logging of:
- Repository name and owner
- GitHub actor
- Token availability
- Workflow permissions

### 2. Basic API Access Tests
Before attempting package API calls, the workflow now:
- Tests basic GitHub API connectivity
- Verifies repository access
- Confirms token validity

### 3. Enhanced Error Handling
- Proper capture of API call return codes
- Detailed error messages for different failure scenarios
- Fallback from organization to user endpoints with clear logging

### 4. Package Discovery Debug
- Shows total number of packages found
- Lists all package names before filtering
- Explains what it means if no packages are found

### 5. Improved Test Script
Updated `test-api-access.sh` with:
- Better error messages
- Rate limit checking
- Package listing
- Step-by-step troubleshooting

## Expected Output
The workflow will now provide much more detailed information about:
1. What API endpoints are being tried
2. What packages (if any) are found
3. Why the filtering might not find products/bfx/* packages
4. Specific permission or access issues

## Common Issues to Look For

### 1. No Packages Found
If the debug shows 0 total packages:
- Check https://github.com/bundlecore?tab=packages
- Verify biocontainer workflow has run and published packages
- Ensure packages are public or token has private access

### 2. Packages Found But Wrong Names
If packages exist but don't match `products/bfx/*`:
- The biocontainer workflow may not have run
- Packages might be from the CI workflow instead (bundlecore-containers/*)
- Need to run the biocontainer workflow to create products/bfx/* packages

### 3. Permission Issues
If API calls fail with 401/403:
- GITHUB_TOKEN lacks packages:read permission
- Repository settings may restrict package access
- Organization settings may block token access

## Next Steps
1. Run the workflow to see the detailed debug output
2. Use the test script locally if needed: `GITHUB_TOKEN=xxx ./test-api-access.sh`
3. Based on the output, determine if the issue is permissions, missing packages, or wrong package names