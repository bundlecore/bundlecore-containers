#!/bin/bash
# SARIF validation utility script
# Validates SARIF files against schema and content requirements

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Validation configuration
VERBOSE=false
STRICT=false
SCHEMA_URL="https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json"

# Validation results
TOTAL_FILES=0
VALID_FILES=0
INVALID_FILES=0
WARNINGS=0

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    WARNINGS=$((WARNINGS + 1))
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

log_header() {
    echo -e "${BOLD}${BLUE}$1${NC}"
}

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS] SARIF_FILE [SARIF_FILE...]

Validate SARIF files for GitHub Security integration compliance.

OPTIONS:
    -v, --verbose   Enable verbose output
    -s, --strict    Enable strict validation (fail on warnings)
    --schema-url    Custom SARIF schema URL (default: OASIS SARIF 2.1.0)
    -h, --help      Show this help message

EXAMPLES:
    $0 results.sarif                    # Validate single file
    $0 *.sarif                          # Validate multiple files
    $0 -v --strict results.sarif        # Strict validation with verbose output

VALIDATION CHECKS:
    - JSON syntax validation
    - SARIF schema compliance
    - Required field presence
    - Tool information validation
    - Results structure validation
    - Security severity validation
    - Location URI format validation

EOF
}

# Parse command line arguments
parse_args() {
    local files=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -s|--strict)
                STRICT=true
                shift
                ;;
            --schema-url)
                SCHEMA_URL="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                files+=("$1")
                shift
                ;;
        esac
    done
    
    if [ ${#files[@]} -eq 0 ]; then
        log_error "No SARIF files specified"
        usage
        exit 1
    fi
    
    # Return files array
    printf '%s\n' "${files[@]}"
}

# Validate JSON syntax
validate_json_syntax() {
    local sarif_file="$1"
    
    log_debug "Validating JSON syntax: $sarif_file"
    
    if ! jq empty "$sarif_file" 2>/dev/null; then
        log_error "Invalid JSON syntax in file: $sarif_file"
        return 1
    fi
    
    log_debug "✓ JSON syntax valid"
    return 0
}

# Validate SARIF schema version
validate_sarif_version() {
    local sarif_file="$1"
    
    log_debug "Validating SARIF version"
    
    # Check version field exists
    if ! jq -e 'has("version")' "$sarif_file" >/dev/null; then
        log_error "Missing required field: version"
        return 1
    fi
    
    # Check version is 2.1.0
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
            log_warn "Unexpected schema URL: $schema_url"
            if [ "$STRICT" = true ]; then
                return 1
            fi
        fi
    fi
    
    log_debug "✓ SARIF version valid"
    return 0
}

# Validate required top-level fields
validate_required_fields() {
    local sarif_file="$1"
    
    log_debug "Validating required fields"
    
    local required_fields=("version" "runs")
    
    for field in "${required_fields[@]}"; do
        if ! jq -e "has(\"$field\")" "$sarif_file" >/dev/null; then
            log_error "Missing required field: $field"
            return 1
        fi
    done
    
    # Validate runs is an array
    if ! jq -e '.runs | type == "array"' "$sarif_file" >/dev/null; then
        log_error "Field 'runs' must be an array"
        return 1
    fi
    
    # Validate runs array is not empty
    local runs_count
    runs_count=$(jq '.runs | length' "$sarif_file")
    
    if [ "$runs_count" -eq 0 ]; then
        log_error "Runs array cannot be empty"
        return 1
    fi
    
    log_debug "✓ Required fields valid"
    return 0
}

# Validate tool driver information
validate_tool_driver() {
    local sarif_file="$1"
    
    log_debug "Validating tool driver information"
    
    # Check tool driver exists
    if ! jq -e '.runs[0].tool.driver' "$sarif_file" >/dev/null; then
        log_error "Missing tool driver information"
        return 1
    fi
    
    # Check tool name
    if ! jq -e '.runs[0].tool.driver | has("name")' "$sarif_file" >/dev/null; then
        log_error "Missing tool driver name"
        return 1
    fi
    
    local tool_name
    tool_name=$(jq -r '.runs[0].tool.driver.name' "$sarif_file")
    
    if [ "$tool_name" != "Trivy" ]; then
        log_warn "Unexpected tool name: $tool_name (expected Trivy)"
        if [ "$STRICT" = true ]; then
            return 1
        fi
    fi
    
    # Check tool version (recommended)
    if ! jq -e '.runs[0].tool.driver | has("version")' "$sarif_file" >/dev/null; then
        log_warn "Missing tool version information"
        if [ "$STRICT" = true ]; then
            return 1
        fi
    fi
    
    # Check information URI (recommended)
    if ! jq -e '.runs[0].tool.driver | has("informationUri")' "$sarif_file" >/dev/null; then
        log_warn "Missing tool information URI"
    fi
    
    log_debug "✓ Tool driver information valid"
    return 0
}

# Validate results structure
validate_results_structure() {
    local sarif_file="$1"
    
    log_debug "Validating results structure"
    
    # Check results array exists
    if ! jq -e '.runs[0] | has("results")' "$sarif_file" >/dev/null; then
        log_error "Missing results array"
        return 1
    fi
    
    # Check results is an array
    if ! jq -e '.runs[0].results | type == "array"' "$sarif_file" >/dev/null; then
        log_error "Results must be an array"
        return 1
    fi
    
    local results_count
    results_count=$(jq '.runs[0].results | length' "$sarif_file")
    
    if [ "$results_count" -eq 0 ]; then
        log_debug "No vulnerabilities found (empty results array)"
        return 0
    fi
    
    log_debug "Found $results_count results to validate"
    
    # Validate each result structure
    local result_index=0
    while [ $result_index -lt "$results_count" ]; do
        log_debug "Validating result $((result_index + 1))/$results_count"
        
        local result_path=".runs[0].results[$result_index]"
        
        # Check required result fields
        local required_result_fields=("ruleId" "level" "message")
        for field in "${required_result_fields[@]}"; do
            if ! jq -e "$result_path | has(\"$field\")" "$sarif_file" >/dev/null; then
                log_error "Result $((result_index + 1)) missing required field: $field"
                return 1
            fi
        done
        
        # Validate level values
        local level
        level=$(jq -r "$result_path.level" "$sarif_file")
        
        case "$level" in
            "error"|"warning"|"note"|"info")
                # Valid levels
                ;;
            *)
                log_error "Result $((result_index + 1)) has invalid level: $level"
                return 1
                ;;
        esac
        
        # Check locations array (recommended)
        if ! jq -e "$result_path | has(\"locations\")" "$sarif_file" >/dev/null; then
            log_warn "Result $((result_index + 1)) missing locations array"
        else
            # Validate location structure
            if ! validate_result_locations "$sarif_file" "$result_index"; then
                return 1
            fi
        fi
        
        result_index=$((result_index + 1))
    done
    
    log_debug "✓ Results structure valid"
    return 0
}

# Validate result locations
validate_result_locations() {
    local sarif_file="$1"
    local result_index="$2"
    
    local locations_path=".runs[0].results[$result_index].locations"
    
    # Check locations is an array
    if ! jq -e "$locations_path | type == \"array\"" "$sarif_file" >/dev/null; then
        log_error "Result $((result_index + 1)) locations must be an array"
        return 1
    fi
    
    local locations_count
    locations_count=$(jq "$locations_path | length" "$sarif_file")
    
    if [ "$locations_count" -eq 0 ]; then
        log_warn "Result $((result_index + 1)) has empty locations array"
        return 0
    fi
    
    # Validate first location
    local location_path="$locations_path[0]"
    
    # Check physical location
    if jq -e "$location_path | has(\"physicalLocation\")" "$sarif_file" >/dev/null; then
        local artifact_path="$location_path.physicalLocation.artifactLocation"
        
        if jq -e "$artifact_path | has(\"uri\")" "$sarif_file" >/dev/null; then
            local uri
            uri=$(jq -r "$artifact_path.uri" "$sarif_file")
            
            # Validate URI format for container images
            if [[ "$uri" =~ ^image:// ]]; then
                local image_url="${uri#image://}"
                if [[ ! "$image_url" =~ ^ghcr\.io/.+/products/bfx/.+:.+$ ]]; then
                    log_warn "Result $((result_index + 1)) has unexpected image URI format: $uri"
                fi
            fi
        fi
    fi
    
    return 0
}

# Validate security severity information
validate_security_severity() {
    local sarif_file="$1"
    
    log_debug "Validating security severity information"
    
    # Check if rules array exists
    if ! jq -e '.runs[0].tool.driver | has("rules")' "$sarif_file" >/dev/null; then
        log_debug "No rules array found (optional)"
        return 0
    fi
    
    local rules_count
    rules_count=$(jq '.runs[0].tool.driver.rules | length' "$sarif_file")
    
    if [ "$rules_count" -eq 0 ]; then
        log_debug "Empty rules array"
        return 0
    fi
    
    log_debug "Found $rules_count rules to validate"
    
    # Validate each rule
    local rule_index=0
    while [ $rule_index -lt "$rules_count" ]; do
        local rule_path=".runs[0].tool.driver.rules[$rule_index]"
        
        # Check rule ID
        if ! jq -e "$rule_path | has(\"id\")" "$sarif_file" >/dev/null; then
            log_error "Rule $((rule_index + 1)) missing ID"
            return 1
        fi
        
        # Check security severity if present
        if jq -e "$rule_path.properties | has(\"security-severity\")" "$sarif_file" >/dev/null; then
            local severity
            severity=$(jq -r "$rule_path.properties.\"security-severity\"" "$sarif_file")
            
            # Validate severity is a number
            if ! [[ "$severity" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                log_error "Rule $((rule_index + 1)) has invalid security-severity: $severity"
                return 1
            fi
            
            # Validate severity range (0.0 - 10.0)
            if (( $(echo "$severity < 0.0" | bc -l) )) || (( $(echo "$severity > 10.0" | bc -l) )); then
                log_error "Rule $((rule_index + 1)) security-severity out of range: $severity"
                return 1
            fi
        fi
        
        rule_index=$((rule_index + 1))
    done
    
    log_debug "✓ Security severity information valid"
    return 0
}

# Validate GitHub Security integration requirements
validate_github_security_requirements() {
    local sarif_file="$1"
    
    log_debug "Validating GitHub Security integration requirements"
    
    # Check SARIF version compatibility
    local version
    version=$(jq -r '.version' "$sarif_file")
    
    if [ "$version" != "2.1.0" ]; then
        log_error "GitHub Security requires SARIF version 2.1.0, found: $version"
        return 1
    fi
    
    # Check tool driver name is present
    if ! jq -e '.runs[0].tool.driver.name' "$sarif_file" >/dev/null; then
        log_error "GitHub Security requires tool driver name"
        return 1
    fi
    
    # Validate results have proper structure for GitHub
    local results_count
    results_count=$(jq '.runs[0].results | length' "$sarif_file")
    
    if [ "$results_count" -gt 0 ]; then
        # Check first result has required fields for GitHub
        if ! jq -e '.runs[0].results[0] | has("ruleId") and has("level") and has("message")' "$sarif_file" >/dev/null; then
            log_error "Results missing required fields for GitHub Security integration"
            return 1
        fi
    fi
    
    log_debug "✓ GitHub Security integration requirements valid"
    return 0
}

# Validate a single SARIF file
validate_sarif_file() {
    local sarif_file="$1"
    
    log_header "Validating: $sarif_file"
    
    TOTAL_FILES=$((TOTAL_FILES + 1))
    
    # Check file exists and is readable
    if [ ! -f "$sarif_file" ]; then
        log_error "File not found: $sarif_file"
        INVALID_FILES=$((INVALID_FILES + 1))
        return 1
    fi
    
    if [ ! -r "$sarif_file" ]; then
        log_error "File not readable: $sarif_file"
        INVALID_FILES=$((INVALID_FILES + 1))
        return 1
    fi
    
    # Run validation checks
    local validation_failed=false
    
    if ! validate_json_syntax "$sarif_file"; then
        validation_failed=true
    fi
    
    if [ "$validation_failed" = false ] && ! validate_sarif_version "$sarif_file"; then
        validation_failed=true
    fi
    
    if [ "$validation_failed" = false ] && ! validate_required_fields "$sarif_file"; then
        validation_failed=true
    fi
    
    if [ "$validation_failed" = false ] && ! validate_tool_driver "$sarif_file"; then
        validation_failed=true
    fi
    
    if [ "$validation_failed" = false ] && ! validate_results_structure "$sarif_file"; then
        validation_failed=true
    fi
    
    if [ "$validation_failed" = false ] && ! validate_security_severity "$sarif_file"; then
        validation_failed=true
    fi
    
    if [ "$validation_failed" = false ] && ! validate_github_security_requirements "$sarif_file"; then
        validation_failed=true
    fi
    
    # Update counters
    if [ "$validation_failed" = true ]; then
        log_error "✗ Validation failed: $sarif_file"
        INVALID_FILES=$((INVALID_FILES + 1))
        return 1
    else
        log_info "✓ Validation passed: $sarif_file"
        VALID_FILES=$((VALID_FILES + 1))
        return 0
    fi
}

# Print validation summary
print_summary() {
    echo ""
    log_header "Validation Summary"
    
    echo "Total files: $TOTAL_FILES"
    echo "Valid files: $VALID_FILES"
    echo "Invalid files: $INVALID_FILES"
    echo "Warnings: $WARNINGS"
    
    if [ $TOTAL_FILES -gt 0 ]; then
        local success_rate
        success_rate=$(( (VALID_FILES * 100) / TOTAL_FILES ))
        echo "Success rate: ${success_rate}%"
    fi
    
    echo ""
    if [ $INVALID_FILES -eq 0 ]; then
        if [ $WARNINGS -eq 0 ] || [ "$STRICT" = false ]; then
            log_info "🎉 All SARIF files are valid!"
        else
            log_warn "⚠️  All files valid but with warnings (strict mode enabled)"
        fi
    else
        log_error "❌ Some SARIF files are invalid!"
    fi
}

# Main execution
main() {
    # Parse command line arguments
    local files
    mapfile -t files < <(parse_args "$@")
    
    # Print header
    log_header "SARIF Validation Tool"
    echo "Files to validate: ${#files[@]}"
    echo "Verbose: $VERBOSE"
    echo "Strict mode: $STRICT"
    echo ""
    
    # Check required tools
    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq is required for SARIF validation"
        exit 1
    fi
    
    if ! command -v bc >/dev/null 2>&1; then
        log_error "bc is required for numeric validation"
        exit 1
    fi
    
    # Validate each file
    local overall_success=true
    
    for sarif_file in "${files[@]}"; do
        if ! validate_sarif_file "$sarif_file"; then
            overall_success=false
        fi
        echo ""
    done
    
    # Print summary
    print_summary
    
    # Determine exit code
    local exit_code=0
    
    if [ $INVALID_FILES -gt 0 ]; then
        exit_code=1
    elif [ "$STRICT" = true ] && [ $WARNINGS -gt 0 ]; then
        exit_code=1
    fi
    
    exit $exit_code
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi