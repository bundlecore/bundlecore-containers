# Design Document

## Overview

The Trivy Security Scan workflow is a separate GitHub Action that performs automated vulnerability scanning on container images published to GitHub Container Registry (ghcr.io) by the existing biocontainer retagging workflow. It leverages the official Trivy Action from Aqua Security to scan images and upload results to GitHub's Security tab in SARIF format.

## Architecture

### Workflow Trigger Strategy
- **Scheduled Execution**: Uses cron schedule to run weekly (e.g., every Sunday at 2 AM UTC)
- **Manual Trigger**: Supports `workflow_dispatch` for on-demand execution
- **Independent Operation**: Runs separately from the image publishing workflow to avoid coupling

### Image Discovery Mechanism
The workflow will discover images to scan by:
1. Using GitHub Packages API to list all published container packages in the repository
2. Filtering packages that match the `products/bfx/*` pattern
3. Retrieving all available tags/versions for each package
4. This approach ensures we only scan images that actually exist and are published

### Scanning Strategy
- **Batch Processing**: Scan images sequentially to manage resource usage
- **Severity Filtering**: Configure Trivy to report only CRITICAL and HIGH severity vulnerabilities
- **Output Format**: Generate SARIF format for GitHub Security integration

## Components and Interfaces

### GitHub Action Workflow File
**Location**: `.github/workflows/trivy-security-scan.yaml`

**Key Components**:
- Trigger configuration (schedule + manual)
- Job definition with appropriate permissions
- Steps for checkout, image discovery, and scanning

### Image Discovery Script
**Purpose**: Generate list of published images to scan using GitHub API
**Input**: GitHub Packages API responses
**Output**: List of ghcr.io image URLs with tags
**Logic**:
```bash
# Get all packages for the repository
curl -H "Authorization: Bearer $GITHUB_TOKEN" \
     -H "Accept: application/vnd.github.v3+json" \
     "https://api.github.com/orgs/${GITHUB_REPOSITORY_OWNER}/packages?package_type=container" | \
jq -r '.[] | select(.name | startswith("products/bfx/")) | .name' | \
while read package_name; do
  # Get all versions for each package
  curl -H "Authorization: Bearer $GITHUB_TOKEN" \
       -H "Accept: application/vnd.github.v3+json" \
       "https://api.github.com/orgs/${GITHUB_REPOSITORY_OWNER}/packages/container/${package_name}/versions" | \
  jq -r '.[].metadata.container.tags[]?' | \
  while read tag; do
    echo "ghcr.io/${GITHUB_REPOSITORY_OWNER}/${package_name}:${tag}"
  done
done
```

### Trivy Scanning Integration
**Action**: `aquasecurity/trivy-action@master`
**Configuration**:
- Image type scanning
- SARIF output format
- Severity filtering (CRITICAL,HIGH)
- Upload to GitHub Security

## Data Models

### Scan Results Structure
```yaml
# SARIF format output structure
runs:
  - tool:
      driver:
        name: "Trivy"
    results:
      - ruleId: "CVE-XXXX-XXXX"
        level: "error"  # for CRITICAL/HIGH
        message:
          text: "Vulnerability description"
        locations:
          - physicalLocation:
              artifactLocation:
                uri: "image://ghcr.io/org/products/bfx/tool:tag"
```

### Image Metadata
```yaml
# Per-image scan metadata
image_url: "ghcr.io/{org}/products/bfx/{tool}:{tag}"
tool_name: "{tool}"
tag: "{version}"
scan_timestamp: "2024-XX-XX"
vulnerability_count:
  critical: N
  high: N
```

## Error Handling

### Image Access Errors
- **Registry Authentication**: Use GITHUB_TOKEN for both API and ghcr.io access
- **API Rate Limits**: Handle GitHub API rate limiting gracefully
- **Network Issues**: Implement retry logic for transient API and registry failures

### Scan Failures
- **Individual Image Failures**: Continue processing remaining images
- **Trivy Tool Errors**: Log detailed error messages
- **SARIF Upload Failures**: Provide fallback artifact upload

### Resource Management
- **Memory Limits**: Monitor scan memory usage for large images
- **Timeout Handling**: Set reasonable timeouts for individual scans
- **Rate Limiting**: Respect registry rate limits

## Testing Strategy

### Unit Testing Approach
- **API Integration**: Test GitHub Packages API calls with mock responses
- **Package Filtering**: Verify correct filtering of bfx packages
- **Error Handling**: Test various API failure scenarios

### Integration Testing
- **End-to-End Workflow**: Test complete workflow execution
- **SARIF Upload**: Verify results appear in GitHub Security tab
- **Schedule Testing**: Validate cron trigger functionality

### Security Testing
- **Permission Validation**: Ensure minimal required permissions
- **Token Security**: Verify secure handling of GITHUB_TOKEN
- **Output Sanitization**: Ensure no sensitive data in logs

## Implementation Considerations

### Performance Optimization
- **Parallel Scanning**: Consider matrix strategy for large image sets
- **Caching**: Leverage GitHub Actions caching for Trivy database
- **Incremental Scanning**: Future enhancement to scan only new/updated images

### Monitoring and Observability
- **Workflow Status**: Clear success/failure indicators
- **Scan Metrics**: Log number of images scanned and vulnerabilities found
- **Execution Time**: Monitor workflow duration for performance tracking

### Security Best Practices
- **Minimal Permissions**: Use least privilege principle
- **Secure Defaults**: Enable security features by default
- **Audit Trail**: Maintain clear logs of scanning activities