#!/bin/bash

# Test script to verify GitHub API access for container packages
# This helps debug the Trivy security scan workflow

set -e

ORG_NAME="bundlecore"
echo "Testing GitHub API access for organization: $ORG_NAME"
echo ""

# Check if GITHUB_TOKEN is set
if [ -z "$GITHUB_TOKEN" ]; then
  echo "Error: GITHUB_TOKEN environment variable not set"
  echo "Usage: GITHUB_TOKEN=your_token ./test-api-access.sh"
  echo ""
  echo "The token needs 'packages:read' permission."
  exit 1
fi

echo "🔍 Basic API Tests:"
echo "=================="

# Test basic API access
echo "→ Testing basic API connectivity..."
if curl -s -f -H "Authorization: Bearer $GITHUB_TOKEN" \
          -H "Accept: application/vnd.github.v3+json" \
          "https://api.github.com/user" > /dev/null; then
  echo "✓ Basic API access successful"
else
  echo "✗ Basic API access failed - token may be invalid"
  exit 1
fi

# Test rate limit info
echo "→ Checking API rate limits..."
RATE_LIMIT=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
                   -H "Accept: application/vnd.github.v3+json" \
                   "https://api.github.com/rate_limit")
REMAINING=$(echo "$RATE_LIMIT" | jq -r '.rate.remaining // "unknown"')
echo "  API calls remaining: $REMAINING"

echo ""
echo "📦 Package API Tests:"
echo "===================="

# Function to make API calls with detailed error reporting
make_api_call() {
  local url="$1"
  local endpoint_name="$2"
  echo "→ Testing $endpoint_name..."
  echo "  URL: $url"
  
  local response
  local http_code
  
  response=$(curl -s -w "%{http_code}" \
                 --max-time 30 \
                 -H "Authorization: Bearer $GITHUB_TOKEN" \
                 -H "Accept: application/vnd.github.v3+json" \
                 "$url")
  
  http_code="${response: -3}"
  response="${response%???}"
  
  echo "  HTTP Status: $http_code"
  
  case "$http_code" in
    200)
      echo "  ✓ Success"
      local count=$(echo "$response" | jq '. | length' 2>/dev/null || echo "0")
      echo "  → Found $count packages"
      if [ "$count" -gt 0 ]; then
        echo "  → Package names:"
        echo "$response" | jq -r '.[].name' 2>/dev/null | head -5 | sed 's/^/    - /'
        if [ "$count" -gt 5 ]; then
          echo "    ... and $((count - 5)) more"
        fi
      fi
      return 0
      ;;
    401)
      echo "  ✗ Authentication failed"
      echo "    → Check GITHUB_TOKEN permissions"
      return 1
      ;;
    403)
      echo "  ✗ Access forbidden"
      echo "    → Token may lack 'packages:read' permission"
      echo "    → Or packages may be private"
      return 1
      ;;
    404)
      echo "  ✗ Not found"
      echo "    → Organization/user may not exist"
      echo "    → Or no packages published"
      return 1
      ;;
    *)
      echo "  ✗ Unexpected response (HTTP $http_code)"
      echo "    → Response: $(echo "$response" | head -c 100)..."
      return 1
      ;;
  esac
}

# Test organization endpoint
if make_api_call "https://api.github.com/orgs/${ORG_NAME}/packages?package_type=container&per_page=10" "organization packages endpoint"; then
  echo ""
  echo "✅ Organization endpoint successful - workflow should work!"
else
  echo ""
  echo "⚠️  Organization endpoint failed, trying user endpoint..."
  
  # Test user endpoint
  if make_api_call "https://api.github.com/users/${ORG_NAME}/packages?package_type=container&per_page=10" "user packages endpoint"; then
    echo ""
    echo "✅ User endpoint successful - workflow should work!"
  else
    echo ""
    echo "❌ Both endpoints failed"
    echo ""
    echo "🔧 Troubleshooting Steps:"
    echo "========================"
    echo "1. Check if packages exist: https://github.com/$ORG_NAME?tab=packages"
    echo "2. Verify GITHUB_TOKEN has 'packages:read' scope"
    echo "3. If packages are private, ensure token has access"
    echo "4. Try with a personal access token with full permissions"
    echo ""
    echo "For GitHub Actions, ensure the workflow has:"
    echo "  permissions:"
    echo "    packages: read"
  fi
fi

echo ""
echo "Test completed."