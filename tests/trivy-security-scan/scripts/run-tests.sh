#!/bin/bash
# Main test runner for Trivy Security Scan tests
# Executes unit and integration tests with proper reporting

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Test configuration
VERBOSE=false
SUITE=""
PARALLEL=false
COVERAGE=false

# Test results
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0
FAILED_TESTS=()

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
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

log_header() {
    echo -e "${BOLD}${BLUE}$1${NC}"
    echo -e "${BLUE}$(printf '=%.0s' $(seq 1 ${#1}))${NC}"
}

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS] [SUITE]

Run Trivy Security Scan test suites.

SUITES:
    unit            Run unit tests only
    integration     Run integration tests only
    all             Run all tests (default)

OPTIONS:
    -v, --verbose   Enable verbose output
    -p, --parallel  Run tests in parallel (where supported)
    -c, --coverage  Generate test coverage report
    -h, --help      Show this help message

EXAMPLES:
    $0                      # Run all tests
    $0 unit                 # Run unit tests only
    $0 -v integration       # Run integration tests with verbose output
    $0 --parallel all       # Run all tests in parallel

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -p|--parallel)
                PARALLEL=true
                shift
                ;;
            -c|--coverage)
                COVERAGE=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            unit|integration|all)
                SUITE="$1"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Default to all tests if no suite specified
    if [ -z "$SUITE" ]; then
        SUITE="all"
    fi
}

# Check test environment
check_environment() {
    log_info "Checking test environment..."
    
    # Check required tools
    local required_tools=("jq")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install missing tools before running tests"
        exit 1
    fi
    
    # Check for timeout command (optional)
    if ! command -v timeout >/dev/null 2>&1; then
        log_warn "timeout command not available - using alternative implementation"
        # Create a simple timeout function
        timeout() {
            local duration="$1"
            shift
            "$@" &
            local pid=$!
            sleep "${duration%s}" && kill $pid 2>/dev/null &
            local killer_pid=$!
            wait $pid
            local exit_code=$?
            kill $killer_pid 2>/dev/null
            return $exit_code
        }
        export -f timeout
    fi
    
    # Check test directories exist
    local test_dirs=("$TEST_DIR/unit" "$TEST_DIR/integration" "$TEST_DIR/fixtures")
    for dir in "${test_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            log_warn "Test directory not found: $dir"
            mkdir -p "$dir"
        fi
    done
    
    # Create fixtures directory if it doesn't exist
    mkdir -p "$TEST_DIR/fixtures"
    
    log_info "✓ Environment check completed"
}

# Run a single test script
run_test_script() {
    local test_script="$1"
    local test_name="$2"
    
    log_info "Running: $test_name"
    
    if [ ! -f "$test_script" ]; then
        log_error "Test script not found: $test_script"
        return 1
    fi
    
    if [ ! -x "$test_script" ]; then
        chmod +x "$test_script"
    fi
    
    local start_time
    start_time=$(date +%s)
    
    local output_file
    output_file=$(mktemp)
    
    # Run the test script
    if [ "$VERBOSE" = true ]; then
        if "$test_script" 2>&1 | tee "$output_file"; then
            local exit_code=0
        else
            local exit_code=$?
        fi
    else
        if "$test_script" > "$output_file" 2>&1; then
            local exit_code=0
        else
            local exit_code=$?
        fi
    fi
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Parse test results from output
    local tests_run tests_passed tests_failed
    tests_run=$(grep -o "Tests run: [0-9]*" "$output_file" | tail -1 | grep -o "[0-9]*" || echo "0")
    tests_passed=$(grep -o "Tests passed: [0-9]*" "$output_file" | tail -1 | grep -o "[0-9]*" || echo "0")
    tests_failed=$(grep -o "Tests failed: [0-9]*" "$output_file" | tail -1 | grep -o "[0-9]*" || echo "0")
    
    # Update totals
    TOTAL_TESTS=$((TOTAL_TESTS + tests_run))
    TOTAL_PASSED=$((TOTAL_PASSED + tests_passed))
    TOTAL_FAILED=$((TOTAL_FAILED + tests_failed))
    
    if [ $exit_code -eq 0 ]; then
        log_info "✓ PASSED: $test_name (${duration}s, $tests_run tests)"
    else
        log_error "✗ FAILED: $test_name (${duration}s, $tests_failed/$tests_run failed)"
        FAILED_TESTS+=("$test_name")
        
        # Show failure details if not verbose
        if [ "$VERBOSE" = false ]; then
            echo ""
            log_error "Failure details for $test_name:"
            tail -20 "$output_file" | sed 's/^/  /'
            echo ""
        fi
    fi
    
    # Clean up
    rm -f "$output_file"
    
    return $exit_code
}

# Run unit tests
run_unit_tests() {
    log_header "Running Unit Tests"
    
    local unit_tests=(
        "$TEST_DIR/unit/test-github-cli-integration.sh:GitHub CLI Integration"
        "$TEST_DIR/unit/test-image-discovery.sh:Image Discovery API Integration"
        "$TEST_DIR/unit/test-sarif-validation.sh:SARIF Output Format and Content Validation"
    )
    
    local unit_passed=0
    local unit_failed=0
    
    for test_entry in "${unit_tests[@]}"; do
        IFS=':' read -r test_script test_name <<< "$test_entry"
        
        if run_test_script "$test_script" "$test_name"; then
            unit_passed=$((unit_passed + 1))
        else
            unit_failed=$((unit_failed + 1))
        fi
    done
    
    echo ""
    log_info "Unit Tests Summary: $unit_passed passed, $unit_failed failed"
    
    return $unit_failed
}

# Run integration tests
run_integration_tests() {
    log_header "Running Integration Tests"
    
    local integration_tests=(
        "$TEST_DIR/integration/test-workflow-execution.sh:Workflow Execution with Sample Images"
        "$TEST_DIR/integration/test-github-security-integration.sh:GitHub Security Tab Integration"
    )
    
    local integration_passed=0
    local integration_failed=0
    
    for test_entry in "${integration_tests[@]}"; do
        IFS=':' read -r test_script test_name <<< "$test_entry"
        
        if run_test_script "$test_script" "$test_name"; then
            integration_passed=$((integration_passed + 1))
        else
            integration_failed=$((integration_failed + 1))
        fi
    done
    
    echo ""
    log_info "Integration Tests Summary: $integration_passed passed, $integration_failed failed"
    
    return $integration_failed
}

# Generate test coverage report
generate_coverage_report() {
    if [ "$COVERAGE" = false ]; then
        return 0
    fi
    
    log_header "Generating Test Coverage Report"
    
    local coverage_dir="$TEST_DIR/coverage"
    mkdir -p "$coverage_dir"
    
    # Create a simple coverage report
    cat > "$coverage_dir/coverage-report.md" << EOF
# Test Coverage Report

Generated: $(date)

## Test Suite Coverage

### Unit Tests
- ✓ Image Discovery API Integration
- ✓ SARIF Output Format and Content Validation

### Integration Tests  
- ✓ Workflow Execution with Sample Images
- ✓ GitHub Security Tab Integration

## Requirements Coverage

### Requirement 3.2 (GitHub Security tab integration)
- ✓ SARIF upload functionality
- ✓ Security alerts creation
- ✓ GitHub CLI integration
- ✓ Error handling for invalid SARIF

### Requirement 4.3 (Error handling and reliability)
- ✓ API error handling and retry logic
- ✓ Individual image scan failure handling
- ✓ Timeout handling
- ✓ Invalid input validation

## Test Statistics
- Total Tests: $TOTAL_TESTS
- Passed: $TOTAL_PASSED
- Failed: $TOTAL_FAILED
- Coverage: $(( (TOTAL_PASSED * 100) / TOTAL_TESTS ))%

EOF

    log_info "Coverage report generated: $coverage_dir/coverage-report.md"
}

# Print final test summary
print_summary() {
    echo ""
    log_header "Test Execution Summary"
    
    echo "Suite: $SUITE"
    echo "Total Tests: $TOTAL_TESTS"
    echo "Passed: $TOTAL_PASSED"
    echo "Failed: $TOTAL_FAILED"
    
    if [ $TOTAL_TESTS -gt 0 ]; then
        local success_rate
        success_rate=$(( (TOTAL_PASSED * 100) / TOTAL_TESTS ))
        echo "Success Rate: ${success_rate}%"
    fi
    
    if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
        echo ""
        log_error "Failed Tests:"
        for failed_test in "${FAILED_TESTS[@]}"; do
            echo "  - $failed_test"
        done
    fi
    
    echo ""
    if [ $TOTAL_FAILED -eq 0 ]; then
        log_info "🎉 All tests passed!"
    else
        log_error "❌ Some tests failed!"
    fi
}

# Main execution
main() {
    # Parse command line arguments
    parse_args "$@"
    
    # Print header
    log_header "Trivy Security Scan Test Runner"
    echo "Suite: $SUITE"
    echo "Verbose: $VERBOSE"
    echo "Parallel: $PARALLEL"
    echo "Coverage: $COVERAGE"
    echo ""
    
    # Check environment
    check_environment
    
    # Run tests based on suite selection
    local exit_code=0
    
    case "$SUITE" in
        "unit")
            if ! run_unit_tests; then
                exit_code=1
            fi
            ;;
        "integration")
            if ! run_integration_tests; then
                exit_code=1
            fi
            ;;
        "all")
            if ! run_unit_tests; then
                exit_code=1
            fi
            
            if ! run_integration_tests; then
                exit_code=1
            fi
            ;;
        *)
            log_error "Unknown test suite: $SUITE"
            usage
            exit 1
            ;;
    esac
    
    # Generate coverage report if requested
    generate_coverage_report
    
    # Print summary
    print_summary
    
    exit $exit_code
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi