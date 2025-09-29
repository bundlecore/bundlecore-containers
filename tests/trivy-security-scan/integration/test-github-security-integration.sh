#!/bin/bash
# Integration tests for GitHub Security tab integration
# Tests SARIF upload and security alerts creation

set -euo pipefail

# Test configuration
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES_DIR="$TEST_DIR/../fixtures"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

run_test() {
    local test_name="$1"
    local test_function="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    echo ""
    log_info "Running test: $test_name"
    
    if $test_function; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_info "✓ PASSED: $test_name"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "✗ FAILED: $test_name"
    fi
}

# Setup test environment for GitHub Security integration
setup_github_security_test_env() {
    # Mock GitHub environment variables
    export GITHUB_REPOSITORY="test-org/biocontainers"
    export GITHUB_REPOSITORY_OWNER="test-org"
    export GITHUB_TOKEN="mock-github-token"
    export GITHUB_WORKSPACE="$TEMP_DIR/workspace"
    export GITHUB_SHA="abc123def456"
    export GITHUB_REF="refs/heads/main"
    export GITHUB_RUN_ID="123456789"
    export GITHUB_RUN_NUMBER="42"
    
    # Create workspace
    mkdir -p "$GITHUB_WORKSPACE"
    mkdir -p "$TEMP_DIR/sarif-uploads"
    
    # Create mock SARIF files for testing
    create_test_sarif_files
    
    # Create mock GitHub CLI for API interactions
    create_mock_github_cli
}

# Create test SARIF files
create_test_sarif_files() {
    # SARIF with critical vulnerabilities
    cat > "$TEMP_DIR/critical-vulns.sarif" << 'EOF'
{
  "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
  "version": "2.1.0",
  "runs": [
    {
      "tool": {
        "driver": {
          "name": "Trivy",
          "version": "0.48.0",
          "informationUri": "https://github.com/aquasecurity/trivy",
          "rules": [
            {
              "id": "CVE-2023-1234",
              "name": "CVE-2023-1234",
              "shortDescription": {
                "text": "Critical vulnerability in libssl"
              },
              "fullDescription": {
                "text": "A critical vulnerability exists in libssl that could allow remote code execution."
              },
              "properties": {
                "security-severity": "9.8",
                "tags": ["security", "external/cwe/cwe-787"]
              }
            },
            {
              "id": "CVE-2023-5678",
              "name": "CVE-2023-5678",
              "shortDescription": {
                "text": "High severity vulnerability in zlib"
              },
              "properties": {
                "security-severity": "7.5",
                "tags": ["security", "external/cwe/cwe-119"]
              }
            }
          ]
        }
      },
      "results": [
        {
          "ruleId": "CVE-2023-1234",
          "ruleIndex": 0,
          "level": "error",
          "message": {
            "text": "Package: libssl1.1\nInstalled Version: 1.1.1f-1ubuntu2.19\nVulnerability CVE-2023-1234\nSeverity: CRITICAL\nFixed Version: 1.1.1f-1ubuntu2.20"
          },
          "locations": [
            {
              "physicalLocation": {
                "artifactLocation": {
                  "uri": "image://ghcr.io/test-org/products/bfx/samtools:1.19.2"
                },
                "region": {
                  "startLine": 1,
                  "startColumn": 1
                }
              }
            }
          ]
        },
        {
          "ruleId": "CVE-2023-5678",
          "ruleIndex": 1,
          "level": "error",
          "message": {
            "text": "Package: zlib1g\nInstalled Version: 1:1.2.11.dfsg-2ubuntu1.3\nVulnerability CVE-2023-5678\nSeverity: HIGH\nFixed Version: 1:1.2.11.dfsg-2ubuntu1.4"
          },
          "locations": [
            {
              "physicalLocation": {
                "artifactLocation": {
                  "uri": "image://ghcr.io/test-org/products/bfx/samtools:1.19.2"
                }
              }
            }
          ]
        }
      ]
    }
  ]
}
EOF

    # SARIF with no vulnerabilities
    cat > "$TEMP_DIR/no-vulns.sarif" << 'EOF'
{
  "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
  "version": "2.1.0",
  "runs": [
    {
      "tool": {
        "driver": {
          "name": "Trivy",
          "version": "0.48.0",
          "informationUri": "https://github.com/aquasecurity/trivy"
        }
      },
      "results": []
    }
  ]
}
EOF

    # Invalid SARIF for error testing
    echo "{ invalid json }" > "$TEMP_DIR/invalid.sarif"
}

# Create mock GitHub CLI
create_mock_github_cli() {
    cat > "$TEMP_DIR/gh" << 'EOF'
#!/bin/bash
# Mock GitHub CLI for testing

case "$1" in
    "api")
        case "$2" in
            "/repos/*/code-scanning/sarifs")
                # Mock SARIF upload API
                if [ "$3" = "--method" ] && [ "$4" = "POST" ]; then
                    # Simulate successful upload
                    echo '{"id": "12345", "url": "https://api.github.com/repos/test-org/biocontainers/code-scanning/analyses/12345"}'
                    exit 0
                else
                    echo "Error: Invalid API call" >&2
                    exit 1
                fi
                ;;
            "/repos/*/code-scanning/analyses")
                # Mock code scanning analyses list
                cat << 'ANALYSES_EOF'
[
  {
    "id": 12345,
    "ref": "refs/heads/main",
    "tool": {
      "name": "Trivy",
      "version": "0.48.0"
    },
    "created_at": "2024-01-15T10:00:00Z",
    "results_count": 2,
    "rules_count": 2
  }
]
ANALYSES_EOF
                exit 0
                ;;
            *)
                echo "Error: Unknown API endpoint: $2" >&2
                exit 1
                ;;
        esac
        ;;
    "auth")
        case "$2" in
            "status")
                echo "✓ Logged in to github.com as test-user (oauth_token)"
                exit 0
                ;;
            *)
                echo "Error: Unknown auth command: $2" >&2
                exit 1
                ;;
        esac
        ;;
    *)
        echo "Error: Unknown command: $1" >&2
        exit 1
        ;;
esac
EOF

    chmod +x "$TEMP_DIR/gh"
    export PATH="$TEMP_DIR:$PATH"
}

# Test: SARIF file preparation for upload
test_sarif_preparation() {
    local sarif_file="$TEMP_DIR/critical-vulns.sarif"
    
    # Validate SARIF file exists and is valid
    if [ ! -f "$sarif_file" ]; then
        log_error "SARIF file not found: $sarif_file"
        return 1
    fi
    
    # Validate JSON structure
    if ! jq empty "$sarif_file" 2>/dev/null; then
        log_error "SARIF file is not valid JSON"
        return 1
    fi
    
    # Check required fields for GitHub Security integration
    local required_fields=("version" "runs")
    for field in "${required_fields[@]}"; do
        if ! jq -e "has(\"$field\")" "$sarif_file" >/dev/null; then
            log_error "SARIF missing required field: $field"
            return 1
        fi
    done
    
    # Validate tool information
    if ! jq -e '.runs[0].tool.driver.name == "Trivy"' "$sarif_file" >/dev/null; then
        log_error "Invalid tool name in SARIF"
        return 1
    fi
    
    # Check results structure
    local results_count
    results_count=$(jq '.runs[0].results | length' "$sarif_file")
    
    if [ "$results_count" -eq 0 ]; then
        log_warn "No vulnerabilities found in SARIF file"
    else
        log_info "Found $results_count vulnerabilities in SARIF file"
    fi
    
    return 0
}

# Test: GitHub CLI authentication
test_github_cli_auth() {
    # Test GitHub CLI is available
    if ! command -v gh >/dev/null 2>&1; then
        log_error "GitHub CLI not available"
        return 1
    fi
    
    # Test authentication status
    if ! gh auth status >/dev/null 2>&1; then
        log_error "GitHub CLI authentication failed"
        return 1
    fi
    
    log_info "GitHub CLI authentication successful"
    return 0
}

# Test: SARIF upload simulation
test_sarif_upload_simulation() {
    local sarif_file="$TEMP_DIR/critical-vulns.sarif"
    local upload_response
    
    # Simulate SARIF upload using GitHub CLI
    upload_response=$(gh api "/repos/$GITHUB_REPOSITORY/code-scanning/sarifs" \
        --method POST \
        --field "commit_sha=$GITHUB_SHA" \
        --field "ref=$GITHUB_REF" \
        --field "sarif=@$sarif_file" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log_error "SARIF upload simulation failed"
        return 1
    fi
    
    # Validate upload response
    if ! echo "$upload_response" | jq empty 2>/dev/null; then
        log_error "Invalid upload response JSON"
        return 1
    fi
    
    # Check response contains expected fields
    local upload_id
    upload_id=$(echo "$upload_response" | jq -r '.id')
    
    if [ "$upload_id" = "null" ] || [ -z "$upload_id" ]; then
        log_error "Upload response missing ID"
        return 1
    fi
    
    log_info "SARIF upload simulation successful (ID: $upload_id)"
    return 0
}

# Test: Security alerts creation verification
test_security_alerts_verification() {
    # Query code scanning analyses to verify upload
    local analyses_response
    analyses_response=$(gh api "/repos/$GITHUB_REPOSITORY/code-scanning/analyses" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log_error "Failed to query code scanning analyses"
        return 1
    fi
    
    # Validate response structure
    if ! echo "$analyses_response" | jq empty 2>/dev/null; then
        log_error "Invalid analyses response JSON"
        return 1
    fi
    
    # Check if analyses exist
    local analyses_count
    analyses_count=$(echo "$analyses_response" | jq '. | length')
    
    if [ "$analyses_count" -eq 0 ]; then
        log_warn "No code scanning analyses found"
        return 0
    fi
    
    # Validate analysis structure
    local first_analysis
    first_analysis=$(echo "$analyses_response" | jq '.[0]')
    
    # Check required fields
    local required_analysis_fields=("id" "tool" "created_at")
    for field in "${required_analysis_fields[@]}"; do
        if ! echo "$first_analysis" | jq -e "has(\"$field\")" >/dev/null; then
            log_error "Analysis missing required field: $field"
            return 1
        fi
    done
    
    # Verify tool information
    local tool_name
    tool_name=$(echo "$first_analysis" | jq -r '.tool.name')
    
    if [ "$tool_name" != "Trivy" ]; then
        log_error "Unexpected tool name in analysis: $tool_name"
        return 1
    fi
    
    log_info "Security alerts verification successful"
    return 0
}

# Test: Multiple SARIF files upload
test_multiple_sarif_upload() {
    local sarif_files=("$TEMP_DIR/critical-vulns.sarif" "$TEMP_DIR/no-vulns.sarif")
    local upload_count=0
    local success_count=0
    
    for sarif_file in "${sarif_files[@]}"; do
        upload_count=$((upload_count + 1))
        log_debug "Uploading SARIF file: $sarif_file"
        
        # Simulate upload
        if gh api "/repos/$GITHUB_REPOSITORY/code-scanning/sarifs" \
            --method POST \
            --field "commit_sha=$GITHUB_SHA" \
            --field "ref=$GITHUB_REF" \
            --field "sarif=@$sarif_file" >/dev/null 2>&1; then
            success_count=$((success_count + 1))
            log_debug "✓ Upload successful: $sarif_file"
        else
            log_debug "✗ Upload failed: $sarif_file"
        fi
    done
    
    log_info "Multiple SARIF upload: $success_count/$upload_count successful"
    
    if [ "$success_count" -ne "$upload_count" ]; then
        log_error "Not all SARIF uploads were successful"
        return 1
    fi
    
    return 0
}

# Test: Error handling for invalid SARIF
test_invalid_sarif_handling() {
    local invalid_sarif="$TEMP_DIR/invalid.sarif"
    
    # Attempt to upload invalid SARIF (should fail)
    if gh api "/repos/$GITHUB_REPOSITORY/code-scanning/sarifs" \
        --method POST \
        --field "commit_sha=$GITHUB_SHA" \
        --field "ref=$GITHUB_REF" \
        --field "sarif=@$invalid_sarif" >/dev/null 2>&1; then
        log_error "Invalid SARIF upload should have failed"
        return 1
    fi
    
    log_info "Invalid SARIF correctly rejected"
    return 0
}

# Test: SARIF metadata validation
test_sarif_metadata_validation() {
    local sarif_file="$TEMP_DIR/critical-vulns.sarif"
    
    # Extract and validate metadata
    local tool_name version results_count
    tool_name=$(jq -r '.runs[0].tool.driver.name' "$sarif_file")
    version=$(jq -r '.runs[0].tool.driver.version' "$sarif_file")
    results_count=$(jq '.runs[0].results | length' "$sarif_file")
    
    # Validate tool metadata
    if [ "$tool_name" != "Trivy" ]; then
        log_error "Invalid tool name: $tool_name"
        return 1
    fi
    
    if [ "$version" = "null" ] || [ -z "$version" ]; then
        log_error "Missing tool version"
        return 1
    fi
    
    # Validate results metadata
    if [ "$results_count" -gt 0 ]; then
        # Check first result has required metadata
        local first_result
        first_result=$(jq '.runs[0].results[0]' "$sarif_file")
        
        local required_result_fields=("ruleId" "level" "message" "locations")
        for field in "${required_result_fields[@]}"; do
            if ! echo "$first_result" | jq -e "has(\"$field\")" >/dev/null; then
                log_error "Result missing required field: $field"
                return 1
            fi
        done
        
        # Validate location metadata
        local location_uri
        location_uri=$(echo "$first_result" | jq -r '.locations[0].physicalLocation.artifactLocation.uri')
        
        if [[ ! "$location_uri" =~ ^image://ghcr\.io/.+/products/bfx/.+:.+$ ]]; then
            log_error "Invalid location URI: $location_uri"
            return 1
        fi
    fi
    
    log_info "SARIF metadata validation successful"
    return 0
}

# Test: GitHub Security tab integration workflow
test_github_security_workflow() {
    local sarif_file="$TEMP_DIR/critical-vulns.sarif"
    
    # Step 1: Prepare SARIF file
    if ! test_sarif_preparation; then
        log_error "SARIF preparation failed"
        return 1
    fi
    
    # Step 2: Upload SARIF
    local upload_response
    upload_response=$(gh api "/repos/$GITHUB_REPOSITORY/code-scanning/sarifs" \
        --method POST \
        --field "commit_sha=$GITHUB_SHA" \
        --field "ref=$GITHUB_REF" \
        --field "sarif=@$sarif_file" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log_error "SARIF upload failed"
        return 1
    fi
    
    # Step 3: Verify upload response
    local upload_id
    upload_id=$(echo "$upload_response" | jq -r '.id')
    
    if [ "$upload_id" = "null" ] || [ -z "$upload_id" ]; then
        log_error "Upload response missing ID"
        return 1
    fi
    
    # Step 4: Verify security alerts are created
    sleep 1  # Brief delay to simulate processing time
    
    if ! test_security_alerts_verification; then
        log_error "Security alerts verification failed"
        return 1
    fi
    
    log_info "Complete GitHub Security workflow test successful"
    return 0
}

# Main test execution
main() {
    log_info "Starting GitHub Security Tab Integration Tests"
    log_info "============================================="
    
    # Setup test environment
    setup_github_security_test_env
    
    # Create fixtures directory
    mkdir -p "$FIXTURES_DIR"
    
    # Run all tests
    run_test "SARIF file preparation for upload" test_sarif_preparation
    run_test "GitHub CLI authentication" test_github_cli_auth
    run_test "SARIF upload simulation" test_sarif_upload_simulation
    run_test "Security alerts creation verification" test_security_alerts_verification
    run_test "Multiple SARIF files upload" test_multiple_sarif_upload
    run_test "Error handling for invalid SARIF" test_invalid_sarif_handling
    run_test "SARIF metadata validation" test_sarif_metadata_validation
    run_test "Complete GitHub Security workflow" test_github_security_workflow
    
    # Print test summary
    echo ""
    log_info "Test Summary"
    log_info "============"
    log_info "Tests run: $TESTS_RUN"
    log_info "Tests passed: $TESTS_PASSED"
    log_info "Tests failed: $TESTS_FAILED"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log_info "✓ All tests passed!"
        exit 0
    else
        log_error "✗ Some tests failed!"
        exit 1
    fi
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi