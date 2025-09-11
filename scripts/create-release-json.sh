#!/bin/bash
# Create release.json for each tool
# This is used while onboarding new tools to bundlecore-containers
# The release.json file contains the repo URL fetched by calling the bundlecore tools API

# Requires jq and curl to be installed
# Requires BCORE_AUTH_TOKEN environment variable to be set with a valid token


for dir in bfx/*/; do
    tool_slug=$(basename "$dir")
    release_file="$dir/release.json"
    api_url="https://bundlecore.com/api/tools/${tool_slug}/versions"

    # Fetch API response and status code in one go
    http_response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer ${BCORE_AUTH_TOKEN}" \
        -H "Content-Type: application/json" \
        "$api_url")

    # Split response and status code
    status_code=$(echo "$http_response" | tail -n1)
    body=$(echo "$http_response" | sed '$d')

    if [ "$status_code" != "200" ]; then
        echo "Error: API responded with status code $status_code for $tool_slug"
        echo "Response body: $body"
    else
        images=$(echo "$body" | jq -r '.data.versions[].registryUrl' | jq -R -s -c 'split("\n")[:-1]')
        echo "{\"images\": $images}" > "$release_file"
        echo "Updated $release_file with images for $tool_slug"
    fi

    
done