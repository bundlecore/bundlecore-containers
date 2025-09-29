#!/bin/bash
# Unit tests for GitHub CLI integration
# Tests the GitHub CLI API calls and authentication

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

# Setup mock GitHub CLI
setup_mock_gh_cli() {
    # Create mock gh command
    cat > "$TEMP_DIR/gh" << 'EOF'
#!/bin/bash
# Mock GitHub CLI for testing

case "$1" in
    "api")
        case "$2" in
            "/orgs/test-org/packages"*)
                # Mock packages response
                echo '[
                  {
                    "id": 12345,
                    "name": "products/bfx/samtools",
                    "package_type": "container",
                    "owner": {"login": "test-org", "type": "Organization"},
                    "version_count": 3,
                    "visibility": "public"
                  },
                  {
                    "id": 12346,
                    "name": "products/bfx/bcftools", 
                    "package_type": "container",
                    "owner": {"login": "test-org", "type": "Organization"},
                    "version_count": 2,
                    "visibility": "public"
                  }
                ]'
                exit 0
                ;;
            "/orgs/test-org/packages/container/products%2Fbfx%2Fsamtools/versions"*)
                # Mock samtools versions
                echo '[
                  {
                    "id": 123451,
                    "name": "1.19.2",
                    "metadata": {
                      "package_type": "container",
                      "container": {"tags": ["1.19.2", "latest"]}
                    }
                  }
                ]'
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
    "--version")
        echo "gh version 2.40.1 (2023-12-13)"
        exit 0
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

# Test: GitHub CLI availability
test_gh_cli_availability() {
    # Test gh command is available
    if ! command -v gh >/dev/null 2>&1; then
        log_error "GitHub CLI not available"
        return 1
    fi
    
    # Test gh version
    local version
    version=$(gh --version 2>/dev/null | head -1)
    
    if [ -z "$version" ]; then
        log_error "Could not get GitHub CLI version"
        return 1
    fi
    
    log_info "GitHub CLI version: $version"
    return 0
}

# Test: GitHub CLI authentication
test_gh_cli_authentication() {
    # Test authentication status
    if ! gh auth status >/dev/null 2>&1; then
        log_error "GitHub CLI authentication failed"
        return 1
    fi
    
    log_info "GitHub CLI authentication successful"
    return 0
}

# Test: GitHub API call for packages
test_gh_api_packages_call() {
    local org_name="test-org"
    local response
    
    # Make API call for packages
    response=$(gh api "/orgs/${org_name}/packages?package_type=container&per_page=100" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log_error "GitHub API call for packages failed"
        return 1
    fi
    
    # Validate response is valid JSON
    if ! echo "$response" | jq empty 2>/dev/null; then
        log_error "Invalid JSON response from packages API"
        return 1
    fi
    
    # Check response contains expected packages
    local package_count
    package_count=$(echo "$response" | jq '. | length')
    
    if [ "$package_count" -eq 0 ]; then
        log_warn "No packages found in response"
    else
        log_info "Found $package_count packages"
    fi
    
    return 0
}

# Test: GitHub API call for package versions
test_gh_api_versions_call() {
    local org_name="test-org"
    local package_name="products/bfx/samtools"
    local encoded_name
    encoded_name=$(echo "$package_name" | sed 's|/|%2F|g')
    
    local response
    response=$(gh api "/orgs/${org_name}/packages/container/${encoded_name}/versions?per_page=100" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log_error "GitHub API call for versions failed"
        return 1
    fi
    
    # Validate response is valid JSON
    if ! echo "$response" | jq empty 2>/dev/null; then
        log_error "Invalid JSON response from versions API"
        return 1
    fi
    
    # Check response contains versions
    local version_count
    version_count=$(echo "$response" | jq '. | length')
    
    if [ "$version_count" -eq 0 ]; then
        log_warn "No versions found in response"
    else
        log_info "Found $version_count versions"
    fi
    
    return 0
}

# Test: Error handling for invalid API calls
test_gh_api_error_handling() {
    # Test invalid endpoint
    if gh api "/invalid/endpoint" >/dev/null 2>&1; then
        log_error "Invalid API endpoint should have failed"
        return 1
    fi
    
    log_info "Error handling for invalid API calls working correctly"
    return 0
}

# Test: Package filtering with GitHub CLI response
test_package_filtering_with_gh_cli() {
    local org_name="test-org"
    local response
    response=$(gh api "/orgs/${org_name}/packages?package_type=container&per_page=100" 2>/dev/null)
    
    # Filter packages that start with "products/bfx/"
    local filtered_packages
    filtered_packages=$(echo "$response" | jq -r '.[] | select(.name | startswith("products/bfx/")) | .name')
    
    local expected_packages="products/bfx/samtools
products/bfx/bcftools"
    
    if [ "$filtered_packages" = "$expected_packages" ]; then
        return 0
    else
        log_error "Package filtering with GitHub CLI failed"
        log_error "Expected: $expected_packages"
        log_error "Got: $filtered_packages"
        return 1
    fi
}

# Test: Complete workflow with GitHub CLI
test_complete_gh_cli_workflow() {
    local org_name="test-org"
    local output_file="$TEMP_DIR/discovered_images.txt"
    
    # Step 1: Get packages
    local packages_response
    packages_response=$(gh api "/orgs/${org_name}/packages?package_type=container&per_page=100" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log_error "Failed to get packages"
        return 1
    fi
    
    # Step 2: Filter and process packages
    echo "$packages_response" | jq -r '.[] | select(.name | startswith("products/bfx/")) | .name' | while read -r package_name; do
        if [ -n "$package_name" ]; then
            # Get versions for this package
            local encoded_name
            encoded_name=$(echo "$package_name" | sed 's|/|%2F|g')
            
            local versions_response
            versions_response=$(gh api "/orgs/${org_name}/packages/container/${encoded_name}/versions?per_page=100" 2>/dev/null)
            
            if [ $? -eq 0 ]; then
                # Extract tags and create image URLs
                echo "$versions_response" | jq -r '.[].metadata.container.tags[]?' | while read -r tag; do
                    if [ -n "$tag" ]; then
                        echo "ghcr.io/${org_name}/${package_name}:${tag}" >> "$output_file"
                    fi
                done
            fi
        fi
    done
    
    # Verify output file was created and contains images
    if [ ! -f "$output_file" ] || [ ! -s "$output_file" ]; then
        log_error "No images discovered in complete workflow"
        return 1
    fi
    
    local image_count
    image_count=$(wc -l < "$output_file")
    
    log_info "Complete GitHub CLI workflow discovered $image_count images"
    return 0
}

# Main test execution
main() {
    log_info "Starting GitHub CLI Integration Tests"
    log_info "===================================="
    
    # Setup mock GitHub CLI
    setup_mock_gh_cli
    
    # Create fixtures directory
    mkdir -p "$FIXTURES_DIR"
    
    # Run all tests
    run_test "GitHub CLI availability" test_gh_cli_availability
    run_test "GitHub CLI authentication" test_gh_cli_authentication
    run_test "GitHub API call for packages" test_gh_api_packages_call
    run_test "GitHub API call for package versions" test_gh_api_versions_call
    run_test "Error handling for invalid API calls" test_gh_api_error_handling
    run_test "Package filtering with GitHub CLI response" test_package_filtering_with_gh_cli
    run_test "Complete GitHub CLI workflow" test_complete_gh_cli_workflow
    
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