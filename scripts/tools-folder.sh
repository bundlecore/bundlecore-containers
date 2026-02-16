#!/bin/bash

# Script to create folders for each tool in the bfx directory
# This is used when onboarding new tools to ensure each has its own folder to store lua files and release.json

# Fetch tools list from API
echo "Fetching tools list from bundlecore API..."
response=$(curl -sS -H "Authorization: Bearer ${BCORE_AUTH_TOKEN}" "https://bundlecore.com/api/tools/meta/slugs")

# Check if curl was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch tools list from API"
    exit 1
fi

# Parse JSON response to extract slugs array
tools_list=$(echo "$response" | jq -r '.data.slugs[]' | tr '\n' ' ')

# Check if jq parsing was successful
if [ -z "$tools_list" ]; then
    echo "Error: Failed to parse tools list from API response"
    echo "Response: $response"
    exit 1
fi

echo "Found $(echo $tools_list | wc -w | tr -d ' ') tools"
for tool in $tools_list
do
    echo "Making folder for $tool"
    if [ -d "bfx/$tool" ]; then
        echo "Folder bfx/$tool already exists, skipping."
    else
        mkdir -p bfx/$tool
        touch bfx/$tool/release.json
        echo "Created folder and release.json for $tool"
    fi
done
