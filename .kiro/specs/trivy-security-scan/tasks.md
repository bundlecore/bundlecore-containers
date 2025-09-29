# Implementation Plan

- [x] 1. Create GitHub Action workflow file structure
  - Create `.github/workflows/trivy-security-scan.yaml` with basic workflow structure
  - Configure workflow triggers (schedule and manual dispatch)
  - Set up job permissions for packages read and security events write
  - _Requirements: 2.1, 2.2_

- [x] 2. Implement image discovery using GitHub API
  - Write script to call GitHub Packages API to list container packages
  - Filter packages matching `products/bfx/*` pattern
  - Extract package names and retrieve all available tags for each package
  - Generate complete ghcr.io image URLs for scanning
  - _Requirements: 1.1, 1.4_

- [x] 3. Configure Trivy security scanning
  - Integrate aquasecurity/trivy-action with appropriate version
  - Configure scan parameters for CRITICAL and HIGH severity filtering
  - Set up SARIF output format for GitHub Security integration
  - Configure registry authentication using GITHUB_TOKEN
  - _Requirements: 1.2, 3.1_

- [x] 4. Implement batch scanning logic
  - Create matrix or sequential scanning strategy for multiple images
  - Add error handling for individual image scan failures
  - Implement continue-on-error logic to process all images even if some fail
  - Add logging for scan progress and results summary
  - _Requirements: 4.2, 4.3_

- [x] 5. Configure SARIF upload and GitHub Security integration
  - Set up github/codeql-action/upload-sarif action
  - Configure proper SARIF file paths and naming
  - Ensure results appear correctly in GitHub Security tab
  - Add metadata for tracking scan timestamps and image information
  - _Requirements: 1.3, 3.1, 3.2_

- [x] 6. Add comprehensive error handling and logging
  - Implement retry logic for API calls and registry access
  - Add proper error messages for common failure scenarios
  - Create status reporting for workflow execution results
  - Add validation for API responses and image accessibility
  - _Requirements: 4.3, 4.4_

- [x] 7. Optimize workflow performance and resource usage
  - Configure appropriate GitHub Actions runner resources
  - Implement Trivy database caching to improve scan speed
  - Add timeout configurations for individual scans
  - Optimize API calls to minimize rate limit impact
  - _Requirements: 4.1, 4.4_

- [x] 8. Create workflow testing and validation
  - Write test cases for image discovery API integration
  - Create validation for SARIF output format and content
  - Test workflow execution with sample images
  - Verify GitHub Security tab integration works correctly
  - _Requirements: 3.2, 4.3_

- [x] 9. Fix GitHub Packages API URL format
  - Update the GitHub API call to use the correct packages endpoint format
  - Change from `/orgs/${ORG_NAME}/packages?package_type=container` to the proper format that includes repository context
  - Test the API call format to ensure it returns the expected package list
  - Verify the API response structure matches the expected format for package filtering
  - _Requirements: 1.1, 1.4_