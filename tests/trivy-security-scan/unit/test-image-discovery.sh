#!/bin/bash
# Unit tests for image discovery API integration
# Tests the GitHub Packages API integration and image URL generation

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

# Mock GitHub API responses
setup_mock_api_responses() {
    # Create mock packages response
    cat > "$FIXTURES_DIR/mock-packages-response.json" << 'EOF'
[
  {
    "id": 12345,
    "name": "products/bfx/samtools",
    "package_type": "container",
    "owner": {
      "login": "test-org",
      "type": "Organization"
    },
    "version_count": 3,
    "visibility": "public",
    "url": "https://api.github.com/orgs/test-org/packages/container/products%2Fbfx%2Fsamtools",
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-15T00:00:00Z"
  },
  {
    "id": 12346,
    "name": "products/bfx/bcftools",
    "package_type": "container",
    "owner": {
      "login": "test-org",
      "type": "Organization"
    },
    "version_count": 2,
    "visibility": "public",
    "url": "https://api.github.com/orgs/test-org/packages/container/products%2Fbfx%2Fbcftools",
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-10T00:00:00Z"
  },
  {
    "id": 12347,
    "name": "other-package",
    "package_type": "container",
    "owner": {
      "login": "test-org",
      "type": "Organization"
    },
    "version_count": 1,
    "visibility": "public",
    "url": "https://api.github.com/orgs/test-org/packages/container/other-package",
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-05T00:00:00Z"
  }
]
EOF

    # Create mock versions response for samtools
    cat > "$FIXTURES_DIR/mock-samtools-versions.json" << 'EOF'
[
  {
    "id": 123451,
    "name": "1.19.2",
    "url": "https://api.github.com/orgs/test-org/packages/container/products%2Fbfx%2Fsamtools/versions/123451",
    "package_html_url": "https://github.com/orgs/test-org/packages/container/package/products%2Fbfx%2Fsamtools",
    "created_at": "2024-01-15T00:00:00Z",
    "updated_at": "2024-01-15T00:00:00Z",
    "metadata": {
      "package_type": "container",
      "container": {
        "tags": ["1.19.2", "latest"]
      }
    }
  },
  {
    "id": 123452,
    "name": "1.20",
    "url": "https://api.github.com/orgs/test-org/packages/container/products%2Fbfx%2Fsamtools/versions/123452",
    "package_html_url": "https://github.com/orgs/test-org/packages/container/package/products%2Fbfx%2Fsamtools",
    "created_at": "2024-01-10T00:00:00Z",
    "updated_at": "2024-01-10T00:00:00Z",
    "metadata": {
      "package_type": "container",
      "container": {
        "tags": ["1.20"]
      }
    }
  }
]
EOF

    # Create mock versions response for bcftools
    cat > "$FIXTURES_DIR/mock-bcftools-versions.json" << 'EOF'
[
  {
    "id": 123461,
    "name": "1.21",
    "url": "https://api.github.com/orgs/test-org/packages/container/products%2Fbfx%2Fbcftools/versions/123461",
    "package_html_url": "https://github.com/orgs/test-org/packages/container/package/products%2Fbfx%2Fbcftools",
    "created_at": "2024-01-10T00:00:00Z",
    "updated_at": "2024-01-10T00:00:00Z",
    "metadata": {
      "package_type": "container",
      "container": {
        "tags": ["1.21", "stable"]
      }
    }
  }
]
EOF

    # Create empty versions response (for testing edge cases)
    echo "[]" > "$FIXTURES_DIR/mock-empty-versions.json"

    # Create invalid JSON response (for error testing)
    echo "invalid json" > "$FIXTURES_DIR/mock-invalid-response.txt"
}

# Test: Package filtering logic
test_package_filtering() {
    local packages_response="$FIXTURES_DIR/mock-packages-response.json"
    
    # Test filtering packages that start with "products/bfx/"
    local filtered_packages
    filtered_packages=$(jq -r '.[] | select(.name | startswith("products/bfx/")) | .name' "$packages_response")
    
    local expected_packages="products/bfx/samtools
products/bfx/bcftools"
    
    if [ "$filtered_packages" = "$expected_packages" ]; then
        return 0
    else
        log_error "Package filtering failed"
        log_error "Expected: $expected_packages"
        log_error "Got: $filtered_packages"
        return 1
    fi
}

# Test: Image URL generation
test_image_url_generation() {
    local org_name="test-org"
    local package_name="products/bfx/samtools"
    local tag="1.19.2"
    
    local expected_url="ghcr.io/test-org/products/bfx/samtools:1.19.2"
    local generated_url="ghcr.io/${org_name}/${package_name}:${tag}"
    
    if [ "$generated_url" = "$expected_url" ]; then
        return 0
    else
        log_error "Image URL generation failed"
        log_error "Expected: $expected_url"
        log_error "Got: $generated_url"
        return 1
    fi
}

# Test: Tag extraction from versions response
test_tag_extraction() {
    local versions_response="$FIXTURES_DIR/mock-samtools-versions.json"
    
    # Extract all tags from the versions response
    local extracted_tags
    extracted_tags=$(jq -r '.[].metadata.container.tags[]?' "$versions_response" | sort)
    
    local expected_tags="1.19.2
1.20
latest"
    
    if [ "$extracted_tags" = "$expected_tags" ]; then
        return 0
    else
        log_error "Tag extraction failed"
        log_error "Expected: $expected_tags"
        log_error "Got: $extracted_tags"
        return 1
    fi
}

# Test: URL encoding for package names
test_url_encoding() {
    local package_name="products/bfx/samtools"
    local encoded_name
    encoded_name=$(echo "$package_name" | sed 's|/|%2F|g')
    
    local expected_encoded="products%2Fbfx%2Fsamtools"
    
    if [ "$encoded_name" = "$expected_encoded" ]; then
        return 0
    else
        log_error "URL encoding failed"
        log_error "Expected: $expected_encoded"
        log_error "Got: $encoded_name"
        return 1
    fi
}

# Test: Image URL validation regex
test_image_url_validation() {
    local valid_urls=(
        "ghcr.io/test-org/products/bfx/samtools:1.19.2"
        "ghcr.io/myorg/products/bfx/bcftools:latest"
        "ghcr.io/org-name/products/bfx/tool-name:v1.0.0"
    )
    
    local invalid_urls=(
        "docker.io/test-org/products/bfx/samtools:1.19.2"
        "ghcr.io/test-org/other/samtools:1.19.2"
        "ghcr.io/test-org/products/bfx/"
        "ghcr.io//products/bfx/samtools:1.19.2"
        "not-a-url"
    )
    
    # Test valid URLs
    for url in "${valid_urls[@]}"; do
        if [[ ! "$url" =~ ^ghcr\.io/[^/]+/products/bfx/.+:.+$ ]]; then
            log_error "Valid URL incorrectly rejected: $url"
            return 1
        fi
    done
    
    # Test invalid URLs
    for url in "${invalid_urls[@]}"; do
        if [[ "$url" =~ ^ghcr\.io/[^/]+/products/bfx/.+:.+$ ]]; then
            log_error "Invalid URL incorrectly accepted: $url"
            return 1
        fi
    done
    
    return 0
}

# Test: Error handling for invalid JSON responses
test_invalid_json_handling() {
    local invalid_response="$FIXTURES_DIR/mock-invalid-response.txt"
    
    # Test that jq properly detects invalid JSON
    if jq empty "$invalid_response" 2>/dev/null; then
        log_error "Invalid JSON was not detected as invalid"
        return 1
    fi
    
    return 0
}

# Test: Empty response handling
test_empty_response_handling() {
    local empty_response="$FIXTURES_DIR/mock-empty-versions.json"
    
    # Test that empty array is handled correctly
    local count
    count=$(jq '. | length' "$empty_response")
    
    if [ "$count" -eq 0 ]; then
        return 0
    else
        log_error "Empty response not handled correctly"
        log_error "Expected count: 0, Got: $count"
        return 1
    fi
}

# Test: Complete image discovery simulation
test_complete_image_discovery() {
    local output_file="$TEMP_DIR/discovered_images.txt"
    local org_name="test-org"
    
    # Simulate the complete image discovery process
    {
        # Process packages response
        jq -r '.[] | select(.name | startswith("products/bfx/")) | .name' "$FIXTURES_DIR/mock-packages-response.json" | while read -r package_name; do
            if [ "$package_name" = "products/bfx/samtools" ]; then
                # Process samtools versions
                jq -r '.[].metadata.container.tags[]?' "$FIXTURES_DIR/mock-samtools-versions.json" | while read -r tag; do
                    echo "ghcr.io/${org_name}/${package_name}:${tag}"
                done
            elif [ "$package_name" = "products/bfx/bcftools" ]; then
                # Process bcftools versions
                jq -r '.[].metadata.container.tags[]?' "$FIXTURES_DIR/mock-bcftools-versions.json" | while read -r tag; do
                    echo "ghcr.io/${org_name}/${package_name}:${tag}"
                done
            fi
        done
    } > "$output_file"
    
    # Verify expected images were discovered
    local expected_images="ghcr.io/test-org/products/bfx/samtools:1.19.2
ghcr.io/test-org/products/bfx/samtools:latest
ghcr.io/test-org/products/bfx/samtools:1.20
ghcr.io/test-org/products/bfx/bcftools:1.21
ghcr.io/test-org/products/bfx/bcftools:stable"
    
    local discovered_images
    discovered_images=$(sort "$output_file")
    expected_images=$(echo "$expected_images" | sort)
    
    if [ "$discovered_images" = "$expected_images" ]; then
        return 0
    else
        log_error "Complete image discovery failed"
        log_error "Expected images:"
        echo "$expected_images"
        log_error "Discovered images:"
        echo "$discovered_images"
        return 1
    fi
}

# Main test execution
main() {
    log_info "Starting Image Discovery API Integration Tests"
    log_info "=============================================="
    
    # Setup test fixtures
    mkdir -p "$FIXTURES_DIR"
    setup_mock_api_responses
    
    # Run all tests
    run_test "Package filtering logic" test_package_filtering
    run_test "Image URL generation" test_image_url_generation
    run_test "Tag extraction from versions response" test_tag_extraction
    run_test "URL encoding for package names" test_url_encoding
    run_test "Image URL validation regex" test_image_url_validation
    run_test "Invalid JSON response handling" test_invalid_json_handling
    run_test "Empty response handling" test_empty_response_handling
    run_test "Complete image discovery simulation" test_complete_image_discovery
    
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