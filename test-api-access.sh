#!/bin/bash

# Test script to verify GitHub API access for container packages
# This helps debug the Trivy security scan workflow

set -e

ORG_NAME="bundlecore"
echo "Testing GitHub API access for organization: $ORG_NAME"

# Function to make API calls (simplified version of the workflow function)
make_api_call() {
  local url="$1"
  echo "Testing API endpoint: $url"
  
  if [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: GITHUB_TOKEN environment variable not set"
    echo "Please set GITHUB_TOKEN with a token that has 'packages:read' permission"
    return 1
  fi
  
  local response
  local http_code
  
  response=$(curl -s -w "%{http_code}" \
                 --max-time 30 \
                 -H "Authorization: Bearer $GITHUB_TOKEN" \
                 -H "Accept: application/vnd.github.v3+json" \
                 "$url")
  
  http_code="${response: -3}"
  response="${response%???}"
  
  echo "HTTP Status: $http_code"
  
  case "$http_code" in
    200)
      echo "✓ API call successful"
      echo "Response preview: $(echo "$response" | head -c 200)..."
      return 0
      ;;
    401)
      echo "✗ Authentication failed - check GITHUB_TOKEN permissions"
      return 1
      ;;
    403)
      echo "✗ Access forbidden - check repository/organization permissions"
      return 1
      ;;
    404)
      echo "✗ Resource not found - organization/packages may not exist"
      return 1
      ;;
    *)
      echo "✗ Unexpected response (HTTP $http_code)"
      echo "Response: $response"
      return 1
      ;;
  esac
}

echo ""
echo "1. Testing organization packages endpoint..."
if make_api_call "https://api.github.com/orgs/${ORG_NAME}/packages?package_type=container&per_page=10"; then
  echo "✓ Organization endpoint works"
else
  echo "✗ Organization endpoint failed"
  
  echo ""
  echo "2. Testing user packages endpoint..."
  if make_api_call "https://api.github.com/users/${ORG_NAME}/packages?package_type=container&per_page=10"; then
    echo "✓ User endpoint works"
  else
    echo "✗ User endpoint also failed"
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Verify GITHUB_TOKEN has 'packages:read' permission"
    echo "2. Check if any container packages exist for $ORG_NAME"
    echo "3. Ensure packages are public or token has access to private packages"
    echo "4. Verify organization/user name is correct"
  fi
fi

echo ""
echo "Test completed."