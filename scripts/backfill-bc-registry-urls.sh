#!/bin/bash

# One-time script to backfill missing bcRegistryUrl values in BundleCore
# This script checks all tools in bfx/ and updates their versions in BundleCore
# if the image exists in GHCR but bcRegistryUrl is empty

set -e

GHCR_ORG="${GHCR_ORG:-bundlecore}"
PROD_DOMAIN="bfx"

if [ -z "$BCORE_AUTH_TOKEN" ]; then
    echo "Error: BCORE_AUTH_TOKEN environment variable is not set"
    exit 1
fi

echo "========================================="
echo "BundleCore bcRegistryUrl Backfill Script"
echo "========================================="
echo ""

# Function to update BundleCore with bcRegistryUrl
update_bundlecore_tool_version() {
    local app_name=$1
    local version=$2
    local original_image=$3
    local bc_registry_url=$4

    echo "  Checking BundleCore for $app_name version $version..."

    # Fetch existing versions from BundleCore
    local versions_data=$(curl -sS -H "Authorization: Bearer ${BCORE_AUTH_TOKEN}" "https://bundlecore.com/api/tools/${app_name}/versions")

    if [ -z "$versions_data" ]; then
        echo "  ⚠️  Warning: Failed to fetch versions for $app_name from BundleCore API" >&2
        return 1
    fi

    # Check if this version exists and get its bcRegistryUrl
    local existing_version=$(echo "$versions_data" | jq -r --arg ver "$version" '.data.versions[] | select(.version == $ver)')
    
    if [ -z "$existing_version" ] || [ "$existing_version" == "null" ]; then
        echo "  ℹ️  Version $version does not exist in BundleCore for $app_name"
        return 0
    fi

    local existing_bc_registry=$(echo "$existing_version" | jq -r '.bcRegistryUrl')
    
    if [ -n "$existing_bc_registry" ] && [ "$existing_bc_registry" != "" ] && [ "$existing_bc_registry" != "null" ]; then
        echo "  ✓ Version $version already has bcRegistryUrl: $existing_bc_registry"
        return 0
    fi
    
    echo "  📝 Version $version exists but bcRegistryUrl is empty, updating..."
    
    # Update the existing version with bcRegistryUrl
    local updated_body=$(echo "$existing_version" | jq \
        --arg bc_registry "$bc_registry_url" \
        --arg registry "$original_image" \
        '.bcRegistryUrl = $bc_registry |
        .registryUrl = $registry')

    # PUT to update the existing version
    response=$(curl -sS -w "%{http_code}" -o /tmp/curl_response -X PUT \
        -H "Authorization: Bearer ${BCORE_AUTH_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$updated_body" \
        "https://bundlecore.com/api/tools/${app_name}/versions/${version}")

    if [ "$response" -ne 200 ]; then
        echo "  ❌ Failed to update BundleCore for $app_name. HTTP status: $response" >&2
        echo "  Response body: $(cat /tmp/curl_response)" >&2
        return 1
    fi

    echo "  ✅ Successfully updated version $version for $app_name"
    echo "     bcRegistryUrl: $bc_registry_url"
    echo "     registryUrl: $original_image"
    return 0
}

# Counters
total_tools=0
total_versions=0
updated_count=0
skipped_count=0
failed_count=0

# Process each tool directory
for appdir in bfx/*/; do
    app=$(basename "$appdir")
    slug=$(basename "$appdir" | tr '[:upper:]' '[:lower:]')
    release_json="${appdir}release.json"

    if [ ! -f "$release_json" ]; then
        echo "⏭️  Skipping $app - no release.json"
        continue
    fi

    total_tools=$((total_tools + 1))
    echo ""
    echo "🔍 Processing tool: $app"
    
    images=$(jq -r '.images[]' "$release_json")
    for img in $images; do
        tag="${img##*:}"
        # remove everything after '--' (e.g. '1.21--h3a4d415_1' -> '1.21')
        tag="${tag%%--*}"
        dest="ghcr.io/${GHCR_ORG}/products/${PROD_DOMAIN}/${slug}:${tag}"
        
        total_versions=$((total_versions + 1))
        
        # Check if image exists in GHCR
        echo "  Checking if $dest exists in GHCR..."
        if ! docker manifest inspect "$dest" > /dev/null 2>&1; then
            echo "  ⏭️  Image does not exist in GHCR, skipping"
            skipped_count=$((skipped_count + 1))
            continue
        fi
        
        echo "  ✓ Image exists in GHCR"
        
        # Update BundleCore API
        if update_bundlecore_tool_version "$slug" "$tag" "$img" "$dest"; then
            updated_count=$((updated_count + 1))
        else
            failed_count=$((failed_count + 1))
        fi
    done
done

echo ""
echo "========================================="
echo "Backfill Summary"
echo "========================================="
echo "Tools processed:       $total_tools"
echo "Versions checked:      $total_versions"
echo "✅ Updated:            $updated_count"
echo "⏭️  Skipped:            $skipped_count"
echo "❌ Failed:             $failed_count"
echo "========================================="

if [ $failed_count -gt 0 ]; then
    exit 1
fi

exit 0
