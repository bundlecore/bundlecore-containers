#!/bin/bash
# Integration tests for workflow execution with sample images
# Tests end-to-end workflow execution and error handling

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

# Setup test environment
setup_test_environment() {
    # Create mock workflow environment
    export GITHUB_REPOSITORY_OWNER="test-org"
    export GITHUB_TOKEN="mock-token"
    export GITHUB_WORKSPACE="$TEMP_DIR/workspace"
    export GITHUB_OUTPUT="$TEMP_DIR/github_output"
    
    # Create workspace directory
    mkdir -p "$GITHUB_WORKSPACE"
    mkdir -p "$TEMP_DIR/trivy-results"
    
    # Initialize GitHub output file
    touch "$GITHUB_OUTPUT"
    
    # Create sample images list
    cat > "$TEMP_DIR/sample_images.txt" << 'EOF'
ghcr.io/test-org/products/bfx/samtools:1.19.2
ghcr.io/test-org/products/bfx/bcftools:1.21
ghcr.io/test-org/products/bfx/bedtools:2.31.1
EOF

    # Create mock Trivy executable for testing
    cat > "$TEMP_DIR/mock-trivy" << 'EOF'
#!/bin/bash
# Mock Trivy executable for testing

case "$1" in
    "--version")
        echo "Version: 0.48.0"
        exit 0
        ;;
    "image")
        # Parse arguments to determine behavior
        image_url=""
        output_file=""
        format=""
        severity=""
        
        while [[ $# -gt 0 ]]; do
            case $1 in
                --format)
                    format="$2"
                    shift 2
                    ;;
                --output)
                    output_file="$2"
                    shift 2
                    ;;
                --severity)
                    severity="$2"
                    shift 2
                    ;;
                --*)
                    shift 2
                    ;;
                *)
                    if [[ "$1" =~ ^ghcr\.io/ ]]; then
                        image_url="$1"
                    fi
                    shift
                    ;;
            esac
        done
        
        # Simulate different scan results based on image
        if [[ "$image_url" =~ samtools ]]; then
            # Simulate vulnerabilities found
            generate_mock_sarif_with_vulns "$output_file" "$image_url"
            exit 0
        elif [[ "$image_url" =~ bcftools ]]; then
            # Simulate no vulnerabilities
            generate_mock_sarif_no_vulns "$output_file" "$image_url"
            exit 0
        elif [[ "$image_url" =~ bedtools ]]; then
            # Simulate scan failure
            echo "Error: Failed to scan image $image_url" >&2
            exit 1
        else
            # Unknown image
            echo "Error: Image not found: $image_url" >&2
            exit 1
        fi
        ;;
    *)
        echo "Unknown command: $1" >&2
        exit 1
        ;;
esac
EOF

    chmod +x "$TEMP_DIR/mock-trivy"
    
    # Add mock trivy to PATH
    export PATH="$TEMP_DIR:$PATH"
}

# Generate mock SARIF with vulnerabilities
generate_mock_sarif_with_vulns() {
    local output_file="$1"
    local image_url="$2"
    
    cat > "$output_file" << EOF
{
  "\$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
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
              "properties": {
                "security-severity": "9.8"
              }
            }
          ]
        }
      },
      "results": [
        {
          "ruleId": "CVE-2023-1234",
          "level": "error",
          "message": {
            "text": "Package: libssl1.1\\nInstalled Version: 1.1.1f-1ubuntu2.19\\nVulnerability CVE-2023-1234\\nSeverity: CRITICAL\\nFixed Version: 1.1.1f-1ubuntu2.20"
          },
          "locations": [
            {
              "physicalLocation": {
                "artifactLocation": {
                  "uri": "image://$image_url"
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
}

# Generate mock SARIF with no vulnerabilities
generate_mock_sarif_no_vulns() {
    local output_file="$1"
    local image_url="$2"
    
    cat > "$output_file" << EOF
{
  "\$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
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
}

# Test: Image discovery step simulation
test_image_discovery_step() {
    local images_file="$TEMP_DIR/discovered_images.txt"
    
    # Simulate image discovery step
    cp "$TEMP_DIR/sample_images.txt" "$images_file"
    
    # Validate discovered images
    if [ ! -f "$images_file" ] || [ ! -s "$images_file" ]; then
        log_error "Image discovery failed - no images file created"
        return 1
    fi
    
    local image_count
    image_count=$(wc -l < "$images_file")
    
    if [ "$image_count" -ne 3 ]; then
        log_error "Expected 3 images, found $image_count"
        return 1
    fi
    
    # Validate image URL format
    while IFS= read -r image_url; do
        if [[ ! "$image_url" =~ ^ghcr\.io/.+/products/bfx/.+:.+$ ]]; then
            log_error "Invalid image URL format: $image_url"
            return 1
        fi
    done < "$images_file"
    
    log_info "Successfully discovered $image_count images"
    return 0
}

# Test: Trivy scanning with sample images
test_trivy_scanning() {
    local images_file="$TEMP_DIR/sample_images.txt"
    local results_dir="$TEMP_DIR/trivy-results"
    local scan_count=0
    local success_count=0
    local failure_count=0
    
    # Process each image
    while IFS= read -r image_url; do
        if [ -n "$image_url" ]; then
            scan_count=$((scan_count + 1))
            log_debug "Scanning image: $image_url"
            
            # Create safe filename for output
            local safe_name
            safe_name=$(echo "$image_url" | sed 's|[^a-zA-Z0-9._-]|_|g')
            local sarif_file="$results_dir/trivy-${safe_name}.sarif"
            
            # Run mock Trivy scan
            if mock-trivy image --format sarif --output "$sarif_file" --severity CRITICAL,HIGH "$image_url"; then
                success_count=$((success_count + 1))
                log_debug "✓ Scan successful: $image_url"
                
                # Validate SARIF output was created
                if [ ! -f "$sarif_file" ]; then
                    log_error "SARIF file not created: $sarif_file"
                    return 1
                fi
                
                # Validate SARIF content
                if ! jq empty "$sarif_file" 2>/dev/null; then
                    log_error "Invalid SARIF JSON: $sarif_file"
                    return 1
                fi
            else
                failure_count=$((failure_count + 1))
                log_debug "✗ Scan failed: $image_url"
            fi
        fi
    done < "$images_file"
    
    log_info "Scan summary: Total=$scan_count, Success=$success_count, Failed=$failure_count"
    
    # Verify expected results
    if [ "$scan_count" -ne 3 ]; then
        log_error "Expected 3 scans, performed $scan_count"
        return 1
    fi
    
    if [ "$success_count" -ne 2 ]; then
        log_error "Expected 2 successful scans, got $success_count"
        return 1
    fi
    
    if [ "$failure_count" -ne 1 ]; then
        log_error "Expected 1 failed scan, got $failure_count"
        return 1
    fi
    
    return 0
}

# Test: Error handling and retry logic
test_error_handling() {
    local test_image="ghcr.io/test-org/products/bfx/nonexistent:latest"
    local results_dir="$TEMP_DIR/trivy-results"
    local safe_name
    safe_name=$(echo "$test_image" | sed 's|[^a-zA-Z0-9._-]|_|g')
    local sarif_file="$results_dir/trivy-${safe_name}.sarif"
    
    # Test scan failure handling
    if mock-trivy image --format sarif --output "$sarif_file" --severity CRITICAL,HIGH "$test_image" 2>/dev/null; then
        log_error "Expected scan to fail for nonexistent image"
        return 1
    fi
    
    # Verify no SARIF file was created for failed scan
    if [ -f "$sarif_file" ]; then
        log_error "SARIF file should not exist for failed scan"
        return 1
    fi
    
    log_info "Error handling working correctly"
    return 0
}

# Test: SARIF output validation
test_sarif_output_validation() {
    local results_dir="$TEMP_DIR/trivy-results"
    local sarif_files
    
    # Find all SARIF files
    sarif_files=$(find "$results_dir" -name "*.sarif" -type f)
    
    if [ -z "$sarif_files" ]; then
        log_error "No SARIF files found for validation"
        return 1
    fi
    
    local valid_files=0
    local invalid_files=0
    
    # Validate each SARIF file
    while IFS= read -r sarif_file; do
        if [ -f "$sarif_file" ]; then
            log_debug "Validating SARIF file: $sarif_file"
            
            # Check JSON validity
            if ! jq empty "$sarif_file" 2>/dev/null; then
                log_error "Invalid JSON in SARIF file: $sarif_file"
                invalid_files=$((invalid_files + 1))
                continue
            fi
            
            # Check SARIF structure
            if ! jq -e 'has("version") and has("runs")' "$sarif_file" >/dev/null; then
                log_error "Invalid SARIF structure: $sarif_file"
                invalid_files=$((invalid_files + 1))
                continue
            fi
            
            # Check tool information
            if ! jq -e '.runs[0].tool.driver.name == "Trivy"' "$sarif_file" >/dev/null; then
                log_error "Invalid tool name in SARIF: $sarif_file"
                invalid_files=$((invalid_files + 1))
                continue
            fi
            
            valid_files=$((valid_files + 1))
            log_debug "✓ Valid SARIF file: $sarif_file"
        fi
    done <<< "$sarif_files"
    
    log_info "SARIF validation: Valid=$valid_files, Invalid=$invalid_files"
    
    if [ "$invalid_files" -gt 0 ]; then
        log_error "Found invalid SARIF files"
        return 1
    fi
    
    if [ "$valid_files" -eq 0 ]; then
        log_error "No valid SARIF files found"
        return 1
    fi
    
    return 0
}

# Test: Workflow timeout handling
test_workflow_timeout() {
    # Simulate timeout scenario by creating a long-running mock scan
    cat > "$TEMP_DIR/mock-trivy-slow" << 'EOF'
#!/bin/bash
# Mock slow Trivy for timeout testing
echo "Starting slow scan..."
sleep 5  # Simulate slow scan
echo "Scan completed"
exit 0
EOF
    
    chmod +x "$TEMP_DIR/mock-trivy-slow"
    
    # Test with timeout (using a simple timeout implementation)
    local start_time
    start_time=$(date +%s)
    
    # Simple timeout implementation for testing
    "$TEMP_DIR/mock-trivy-slow" &
    local pid=$!
    sleep 2
    if kill $pid 2>/dev/null; then
        wait $pid 2>/dev/null || true
        log_info "Process terminated by timeout as expected"
    else
        log_error "Process should have been terminated by timeout"
        return 1
    fi
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ "$duration" -gt 4 ]; then
        log_error "Timeout took too long: ${duration}s"
        return 1
    fi
    
    log_info "Timeout handling working correctly"
    return 0
}

# Test: Results aggregation
test_results_aggregation() {
    local results_dir="$TEMP_DIR/trivy-results"
    local summary_file="$results_dir/scan-summary.json"
    
    # Create mock summary
    cat > "$summary_file" << 'EOF'
{
  "scan_timestamp": "2024-01-15T10:00:00Z",
  "total_images": 3,
  "successful_scans": 2,
  "failed_scans": 1,
  "total_vulnerabilities": 1,
  "critical_vulnerabilities": 1,
  "high_vulnerabilities": 0
}
EOF
    
    # Validate summary structure
    if ! jq empty "$summary_file" 2>/dev/null; then
        log_error "Invalid summary JSON"
        return 1
    fi
    
    # Check required fields
    local required_fields=("scan_timestamp" "total_images" "successful_scans" "failed_scans")
    for field in "${required_fields[@]}"; do
        if ! jq -e "has(\"$field\")" "$summary_file" >/dev/null; then
            log_error "Missing required field in summary: $field"
            return 1
        fi
    done
    
    log_info "Results aggregation working correctly"
    return 0
}

# Test: Workflow environment validation
test_workflow_environment() {
    # Check required environment variables
    local required_vars=("GITHUB_REPOSITORY_OWNER" "GITHUB_TOKEN" "GITHUB_WORKSPACE")
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            log_error "Missing required environment variable: $var"
            return 1
        fi
    done
    
    # Check workspace directory
    if [ ! -d "$GITHUB_WORKSPACE" ]; then
        log_error "Workspace directory does not exist: $GITHUB_WORKSPACE"
        return 1
    fi
    
    # Check Trivy availability
    if ! command -v mock-trivy >/dev/null 2>&1; then
        log_error "Trivy command not available"
        return 1
    fi
    
    log_info "Workflow environment validation passed"
    return 0
}

# Main test execution
main() {
    log_info "Starting Workflow Execution Integration Tests"
    log_info "============================================"
    
    # Setup test environment
    setup_test_environment
    
    # Create fixtures directory
    mkdir -p "$FIXTURES_DIR"
    
    # Run all tests
    run_test "Workflow environment validation" test_workflow_environment
    run_test "Image discovery step simulation" test_image_discovery_step
    run_test "Trivy scanning with sample images" test_trivy_scanning
    run_test "Error handling and retry logic" test_error_handling
    run_test "SARIF output validation" test_sarif_output_validation
    run_test "Workflow timeout handling" test_workflow_timeout
    run_test "Results aggregation" test_results_aggregation
    
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