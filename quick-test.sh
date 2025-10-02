#!/bin/bash

# Quick test to verify API access to bundlecore packages
# Usage: GITHUB_TOKEN=your_token ./quick-test.sh

if [ -z "$GITHUB_TOKEN" ]; then
  echo "Please set GITHUB_TOKEN environment variable"
  echo "Usage: GITHUB_TOKEN=your_token ./quick-test.sh"
  exit 1
fi

ORG_NAME="bundlecore"

echo "Testing GitHub API access for $ORG_NAME packages..."
echo ""

# Test organization packages endpoint
echo "1. Testing organization packages endpoint:"
response=$(curl -s -w "%{http_code}" \
               -H "Authorization: Bearer $GITHUB_TOKEN" \
               -H "Accept: application/vnd.github.v3+json" \
               "https://api.github.com/orgs/${ORG_NAME}/packages?package_type=container&per_page=5")

http_code="${response: -3}"
response_body="${response%???}"

echo "   HTTP Status: $http_code"

if [ "$http_code" = "200" ]; then
  echo "   ✓ Success!"
  echo "   Packages found:"
  echo "$response_body" | jq -r '.[].name' | sed 's/^/     - /'
  
  # Check for products/bfx packages specifically
  bfx_count=$(echo "$response_body" | jq -r '.[] | select(.name | startswith("products/bfx/")) | .name' | wc -l)
  echo "   → products/bfx/* packages: $bfx_count"
  
  if [ "$bfx_count" -gt 0 ]; then
    echo "   ✅ Found products/bfx packages - workflow should work!"
  else
    echo "   ⚠️  No products/bfx packages found"
  fi
else
  echo "   ✗ Failed with HTTP $http_code"
  echo "   Response: $response_body"
  
  if [ "$http_code" = "404" ]; then
    echo ""
    echo "2. Trying user packages endpoint:"
    user_response=$(curl -s -w "%{http_code}" \
                         -H "Authorization: Bearer $GITHUB_TOKEN" \
                         -H "Accept: application/vnd.github.v3+json" \
                         "https://api.github.com/users/${ORG_NAME}/packages?package_type=container&per_page=5")
    
    user_http_code="${user_response: -3}"
    user_response_body="${user_response%???}"
    
    echo "   HTTP Status: $user_http_code"
    
    if [ "$user_http_code" = "200" ]; then
      echo "   ✓ User endpoint works!"
      echo "   Packages found:"
      echo "$user_response_body" | jq -r '.[].name' | sed 's/^/     - /'
    else
      echo "   ✗ User endpoint also failed: $user_http_code"
    fi
  fi
fi

echo ""
echo "Test completed."