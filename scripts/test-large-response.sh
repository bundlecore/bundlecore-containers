#!/bin/bash

# Test script to verify large API response handling
# Usage: GITHUB_TOKEN=your_token ./test-large-response.sh

if [ -z "$GITHUB_TOKEN" ]; then
  echo "Please set GITHUB_TOKEN environment variable"
  exit 1
fi

ORG_NAME="bundlecore"

echo "Testing large API response handling..."

# Function that mimics the fixed make_api_call
make_api_call_fixed() {
  local url="$1"
  echo "→ Testing: $url"
  
  local response
  local http_code
  
  response=$(curl -s -w "%{http_code}" \
                 --max-time 30 \
                 -H "Authorization: Bearer $GITHUB_TOKEN" \
                 -H "Accept: application/vnd.github.v3+json" \
                 "$url")
  
  # Don't echo the full response - just extract status
  http_code="${response: -3}"
  response="${response%???}"
  
  case "$http_code" in
    200)
      echo "  ✓ Success (HTTP $http_code)"
      # Return response without echoing
      printf "%s" "$response"
      return 0
      ;;
    *)
      echo "  ✗ Failed (HTTP $http_code)"
      # Safe preview only
      local preview=$(printf "%.200s" "$response" 2>/dev/null || echo "Unable to preview")
      echo "  Preview: ${preview}..."
      return 1
      ;;
  esac
}

# Test the API call
echo ""
echo "1. Testing organization packages endpoint..."
if PACKAGES_RESPONSE=$(make_api_call_fixed "https://api.github.com/orgs/${ORG_NAME}/packages?package_type=container&per_page=100"); then
  echo "✓ API call successful"
  
  # Test JSON parsing
  echo ""
  echo "2. Testing JSON parsing..."
  if echo "$PACKAGES_RESPONSE" | jq empty 2>/dev/null; then
    echo "✓ Valid JSON response"
    
    # Count packages
    TOTAL_COUNT=$(echo "$PACKAGES_RESPONSE" | jq '. | length')
    echo "  → Total packages: $TOTAL_COUNT"
    
    # Look for products/bfx packages
    BFX_COUNT=$(echo "$PACKAGES_RESPONSE" | jq -r '.[] | select(.name | startswith("products/bfx/")) | .name' | wc -l)
    echo "  → products/bfx/* packages: $BFX_COUNT"
    
    if [ "$BFX_COUNT" -gt 0 ]; then
      echo "  → Sample products/bfx/* packages:"
      echo "$PACKAGES_RESPONSE" | jq -r '.[] | select(.name | startswith("products/bfx/")) | .name' | head -5 | sed 's/^/    ✓ /'
      echo ""
      echo "🎉 Success! The workflow should now work properly."
    else
      echo "  → No products/bfx/* packages found"
      echo "  → Sample of all packages:"
      echo "$PACKAGES_RESPONSE" | jq -r '.[].name' | head -5 | sed 's/^/    - /'
    fi
  else
    echo "✗ Invalid JSON response"
  fi
else
  echo "✗ API call failed"
fi

echo ""
echo "Test completed."