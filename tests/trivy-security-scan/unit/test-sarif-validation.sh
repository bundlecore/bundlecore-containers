#!/bin/bash
# Unit tests for SARIF output format and content validation
# Tests SARIF schema compliance and content structure

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

# Create mock SARIF files for testing
setup_mock_sarif_files() {
    # Valid SARIF file with vulnerabilities
    cat > "$FIXTURES_DIR/valid-sarif-with-vulns.sarif" << 'EOF'
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
              "help": {
                "text": "Update to the latest version of libssl to fix this vulnerability."
              },
              "properties": {
                "precision": "very-high",
                "security-severity": "9.8",
                "tags": ["security", "external/cwe/cwe-787"]
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
                  "startColumn": 1,
                  "endLine": 1,
                  "endColumn": 1
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

    # Valid SARIF file with no vulnerabilities
    cat > "$FIXTURES_DIR/valid-sarif-no-vulns.sarif" << 'EOF'
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

    # Invalid SARIF file - missing required fields
    cat > "$FIXTURES_DIR/invalid-sarif-missing-fields.sarif" << 'EOF'
{
  "version": "2.1.0",
  "runs": [
    {
      "results": []
    }
  ]
}
EOF

    # Invalid SARIF file - wrong schema version
    cat > "$FIXTURES_DIR/invalid-sarif-wrong-version.sarif" << 'EOF'
{
  "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
  "version": "1.0.0",
  "runs": []
}
EOF

    # Invalid JSON file
    echo "{ invalid json }" > "$FIXTURES_DIR/invalid-json.sarif"

    # SARIF with multiple vulnerabilities (for testing aggregation)
    cat > "$FIXTURES_DIR/valid-sarif-multiple-vulns.sarif" << 'EOF'
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
              "properties": {
                "security-severity": "9.8"
              }
            },
            {
              "id": "CVE-2023-5678",
              "properties": {
                "security-severity": "7.5"
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
            "text": "Critical vulnerability"
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
        },
        {
          "ruleId": "CVE-2023-5678",
          "level": "error",
          "message": {
            "text": "High severity vulnerability"
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
}

# Test: Basic SARIF JSON structure validation
test_sarif_json_structure() {
    local sarif_file="$FIXTURES_DIR/valid-sarif-with-vulns.sarif"
    
    # Test that file is valid JSON
    if ! jq empty "$sarif_file" 2>/dev/null; then
        log_error "SARIF file is not valid JSON"
        return 1
    fi
    
    # Test required top-level fields
    local required_fields=("version" "runs")
    for field in "${required_fields[@]}"; do
        if ! jq -e "has(\"$field\")" "$sarif_file" >/dev/null; then
            log_error "Missing required field: $field"
            return 1
        fi
    done
    
    return 0
}

# Test: SARIF schema version validation
test_sarif_schema_version() {
    local sarif_file="$FIXTURES_DIR/valid-sarif-with-vulns.sarif"
    
    # Check SARIF version is 2.1.0
    local version
    version=$(jq -r '.version' "$sarif_file")
    
    if [ "$version" != "2.1.0" ]; then
        log_error "Invalid SARIF version: $version (expected 2.1.0)"
        return 1
    fi
    
    # Check schema URL if present
    if jq -e 'has("$schema")' "$sarif_file" >/dev/null; then
        local schema_url
        schema_url=$(jq -r '."$schema"' "$sarif_file")
        
        if [[ ! "$schema_url" =~ sarif-schema-2\.1\.0\.json ]]; then
            log_error "Invalid schema URL: $schema_url"
            return 1
        fi
    fi
    
    return 0
}

# Test: Tool driver information validation
test_tool_driver_info() {
    local sarif_file="$FIXTURES_DIR/valid-sarif-with-vulns.sarif"
    
    # Check tool driver name is Trivy
    local tool_name
    tool_name=$(jq -r '.runs[0].tool.driver.name' "$sarif_file")
    
    if [ "$tool_name" != "Trivy" ]; then
        log_error "Invalid tool name: $tool_name (expected Trivy)"
        return 1
    fi
    
    # Check tool driver has version
    if ! jq -e '.runs[0].tool.driver | has("version")' "$sarif_file" >/dev/null; then
        log_error "Tool driver missing version information"
        return 1
    fi
    
    return 0
}

# Test: Vulnerability results structure
test_vulnerability_results_structure() {
    local sarif_file="$FIXTURES_DIR/valid-sarif-with-vulns.sarif"
    
    # Check results array exists
    if ! jq -e '.runs[0] | has("results")' "$sarif_file" >/dev/null; then
        log_error "Missing results array"
        return 1
    fi
    
    # Check each result has required fields
    local result_count
    result_count=$(jq '.runs[0].results | length' "$sarif_file")
    
    if [ "$result_count" -eq 0 ]; then
        log_warn "No vulnerabilities found in SARIF file"
        return 0
    fi
    
    # Validate first result structure
    local required_result_fields=("ruleId" "level" "message" "locations")
    for field in "${required_result_fields[@]}"; do
        if ! jq -e ".runs[0].results[0] | has(\"$field\")" "$sarif_file" >/dev/null; then
            log_error "Result missing required field: $field"
            return 1
        fi
    done
    
    return 0
}

# Test: Security severity levels
test_security_severity_levels() {
    local sarif_file="$FIXTURES_DIR/valid-sarif-multiple-vulns.sarif"
    
    # Check that results have appropriate severity levels
    local critical_count high_count
    critical_count=$(jq '[.runs[0].results[] | select(.level == "error")] | length' "$sarif_file")
    
    if [ "$critical_count" -eq 0 ]; then
        log_warn "No critical/high severity vulnerabilities found"
    fi
    
    # Validate security-severity properties in rules
    local rules_with_severity
    rules_with_severity=$(jq '[.runs[0].tool.driver.rules[]? | select(has("properties") and .properties | has("security-severity"))] | length' "$sarif_file")
    
    if [ "$rules_with_severity" -gt 0 ]; then
        log_info "Found $rules_with_severity rules with security severity information"
    fi
    
    return 0
}

# Test: Image location validation
test_image_location_validation() {
    local sarif_file="$FIXTURES_DIR/valid-sarif-with-vulns.sarif"
    
    # Check that locations contain proper image URIs
    local image_uris
    image_uris=$(jq -r '.runs[0].results[].locations[].physicalLocation.artifactLocation.uri' "$sarif_file")
    
    while IFS= read -r uri; do
        if [[ ! "$uri" =~ ^image://ghcr\.io/.+/products/bfx/.+:.+$ ]]; then
            log_error "Invalid image URI format: $uri"
            return 1
        fi
    done <<< "$image_uris"
    
    return 0
}

# Test: Invalid SARIF file handling
test_invalid_sarif_handling() {
    local invalid_files=(
        "$FIXTURES_DIR/invalid-sarif-missing-fields.sarif"
        "$FIXTURES_DIR/invalid-sarif-wrong-version.sarif"
        "$FIXTURES_DIR/invalid-json.sarif"
    )
    
    for file in "${invalid_files[@]}"; do
        # Test that validation correctly identifies invalid files
        if validate_sarif_file "$file"; then
            log_error "Invalid SARIF file was incorrectly validated as valid: $file"
            return 1
        fi
    done
    
    return 0
}

# Test: Empty results handling
test_empty_results_handling() {
    local sarif_file="$FIXTURES_DIR/valid-sarif-no-vulns.sarif"
    
    # Validate file structure is correct even with no vulnerabilities
    if ! validate_sarif_file "$sarif_file"; then
        log_error "Valid SARIF file with no vulnerabilities failed validation"
        return 1
    fi
    
    # Check results array is empty
    local result_count
    result_count=$(jq '.runs[0].results | length' "$sarif_file")
    
    if [ "$result_count" -ne 0 ]; then
        log_error "Expected empty results array, got $result_count results"
        return 1
    fi
    
    return 0
}

# Test: SARIF aggregation and summary
test_sarif_aggregation() {
    local sarif_file="$FIXTURES_DIR/valid-sarif-multiple-vulns.sarif"
    
    # Count total vulnerabilities
    local total_vulns
    total_vulns=$(jq '.runs[0].results | length' "$sarif_file")
    
    if [ "$total_vulns" -lt 2 ]; then
        log_error "Expected multiple vulnerabilities for aggregation test"
        return 1
    fi
    
    # Count unique CVEs
    local unique_cves
    unique_cves=$(jq '[.runs[0].results[].ruleId] | unique | length' "$sarif_file")
    
    if [ "$unique_cves" -ne "$total_vulns" ]; then
        log_warn "Duplicate CVEs found in results"
    fi
    
    # Generate summary statistics
    local critical_count high_count
    critical_count=$(jq '[.runs[0].tool.driver.rules[]? | select(.properties."security-severity" | tonumber >= 9.0)] | length' "$sarif_file")
    high_count=$(jq '[.runs[0].tool.driver.rules[]? | select(.properties."security-severity" | tonumber >= 7.0 and tonumber < 9.0)] | length' "$sarif_file")
    
    log_info "Vulnerability summary: Critical=$critical_count, High=$high_count"
    
    return 0
}

# Helper function to validate SARIF file
validate_sarif_file() {
    local sarif_file="$1"
    
    # Check file exists and is readable
    if [ ! -f "$sarif_file" ] || [ ! -r "$sarif_file" ]; then
        return 1
    fi
    
    # Check valid JSON
    if ! jq empty "$sarif_file" 2>/dev/null; then
        return 1
    fi
    
    # Check required fields
    if ! jq -e 'has("version") and has("runs")' "$sarif_file" >/dev/null; then
        return 1
    fi
    
    # Check SARIF version
    local version
    version=$(jq -r '.version' "$sarif_file")
    if [ "$version" != "2.1.0" ]; then
        return 1
    fi
    
    # Check runs array structure
    if ! jq -e '.runs | type == "array" and length > 0' "$sarif_file" >/dev/null; then
        return 1
    fi
    
    # Check tool driver exists
    if ! jq -e '.runs[0].tool.driver | has("name")' "$sarif_file" >/dev/null; then
        return 1
    fi
    
    return 0
}

# Main test execution
main() {
    log_info "Starting SARIF Output Format and Content Validation Tests"
    log_info "========================================================"
    
    # Setup test fixtures
    mkdir -p "$FIXTURES_DIR"
    setup_mock_sarif_files
    
    # Run all tests
    run_test "Basic SARIF JSON structure validation" test_sarif_json_structure
    run_test "SARIF schema version validation" test_sarif_schema_version
    run_test "Tool driver information validation" test_tool_driver_info
    run_test "Vulnerability results structure" test_vulnerability_results_structure
    run_test "Security severity levels" test_security_severity_levels
    run_test "Image location validation" test_image_location_validation
    run_test "Invalid SARIF file handling" test_invalid_sarif_handling
    run_test "Empty results handling" test_empty_results_handling
    run_test "SARIF aggregation and summary" test_sarif_aggregation
    
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