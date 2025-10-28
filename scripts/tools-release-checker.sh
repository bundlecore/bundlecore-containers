   #!/bin/bash

check_quay_tags() {
    local image_name=$1
    # Add limit=3 and order by last_modified to get more tags for comparison
    curl -s "https://quay.io/api/v1/repository/${image_name}/tag/?limit=3&onlyActiveTags=true&orderBy=last_modified" || return 1
}

check_git_source_tags() {
    local app_name=$1 ## tool name eg: bcftools

    # Check if BCORE_AUTH_TOKEN is set
    if [[ -z "$BCORE_AUTH_TOKEN" ]]; then
        echo "BCORE_AUTH_TOKEN is not set. Without this, we cannot fetch tool information from BundleCore API." >&2
        return 1
    fi
    
    # Get the Git repo URL of the tool using BundleCore API. 
    local git_url=$(curl -sS -H "Authorization: Bearer $BCORE_AUTH_TOKEN" "https://bundlecore.com/api/tools/$app_name" | jq -r '.data.tool.codeRepo')
    if [[ ! "$git_url" =~ ^https://github.com/ ]] && [[ ! "$git_url" =~ ^https://gitlab.com/ ]]; then
        echo "Could not find the Git URL for the tool: $app_name" >&2
        return 1
    fi
    echo "Git repo url for $app_name from BundleCore API: $git_url" >&2

    # Find the latest tag from the Git repo
    if [[ "$git_url" =~ ^https://github.com/ ]]; then
        # Extract owner/repo from GitHub URL
        local repo_path=${git_url#https://github.com/}
        repo_path=${repo_path%.git}
        # Get the latest release tag from GitHub API
        latest_version=$(curl -sS  \
            "https://api.github.com/repos/$repo_path/releases/latest" | jq -r '.tag_name')
        
    elif [[ "$git_url" =~ ^https://gitlab.com/ ]]; then
        # Extract project path from GitLab URL
        local project_path=${git_url#https://gitlab.com/}
        project_path=${project_path%.git}
        # URL encode the project path
        local encoded_project_path=$(echo "$project_path" | sed 's/\//%2F/g')
        # Get the latest release tag from GitLab API
        latest_version=$(curl -sSL  \
            "https://gitlab.com/api/v4/projects/$encoded_project_path/releases/permalink/latest" | jq -r '.tag_name')
    else
        echo "Unsupported Git provider $git_url for $app_name" >&2
        return 1
    fi
    echo "$latest_version"
    return 0
}

# Function to check if a tag already exists in release.json (with regex matching)
tag_exists_in_release() {
    local tag=$1
    local current_images=("${@:2}")
    
    for image in "${current_images[@]}"; do
        # Extract tag from image name (everything after the last colon)
        local image_tag="${image##*:}"
        # Check if the git tag is contained within the image tag
        if [[ "$image_tag" =~ .*"$tag".* ]]; then
            return 0  # Tag found
        fi
    done
    return 1  # Tag not found
}

process_release_file() {
    local file_path=$1
    local app_name=$(basename "$(dirname "$file_path")")
    
    
    # Extract the repository name from the first image in release.json
    local repo=$(jq -r '.images[0]' "$file_path" | cut -d':' -f1 | sed 's|quay.io/||')
    # echo "Checking $repo for $app_name..."

    # Get latest git tag
    local latest_git_tag=$(check_git_source_tags "$app_name")
    if [[ -z "$latest_git_tag" || "$latest_git_tag" == "null" ]]; then
        echo "Could not fetch latest git tag for $app_name"
        return
    fi

    echo "Latest version present in Git for $app_name is $latest_git_tag"

    # Check if git tag already exists in release.json using grep
    if grep -q "$latest_git_tag" "$file_path"; then
        echo "Latest git tag $latest_git_tag already exists in release.json for $app_name. No update needed."
        return
    fi

    # echo "New git tag $latest_git_tag found for $app_name. Checking Quay.io..."

    local tags_data=$(check_quay_tags "$repo")

    if [[ $? -eq 0 ]]; then
        # Get tags sorted by last_modified
        local quay_tags=$(echo "$tags_data" | jq -r '.tags | sort_by(.last_modified) | reverse | .[].name')
        local matching_tag=""

        # Find the latest Quay tag that contains the git tag
        while read -r tag; do
            if [[ "$tag" =~ .*"$latest_git_tag".* ]]; then
                matching_tag="$tag"
                break
            fi
        done <<< "$quay_tags"

        if [[ -n "$matching_tag" ]]; then
            # Check if this matching tag already exists in release.json using grep
            if grep -q "$matching_tag" "$file_path"; then
                echo "Matching Quay tag $matching_tag already exists in release.json for $app_name. No update needed."
                return
            fi

            # Add new version to the beginning of images array
            local full_image="quay.io/${repo}:${matching_tag}"
            local image_list=$(jq -r '.images' "$file_path")
            image_list=$(jq --arg img "$full_image" '. |= [$img] + .' <<< "$image_list")
            
            echo "Updating $file_path with new version: $full_image"
            # Update the release.json file
            jq --arg images "$image_list" '.images = ($images|fromjson)' "$file_path" > "$file_path.tmp"
            mv "$file_path.tmp" "$file_path"
            
            # Set updates flag for this specific tool
            echo "updates_${app_name}=true" >> $GITHUB_OUTPUT
            echo "updates_${app_name}=true" >> $GITHUB_ENV
            echo "branch_name_${app_name}=update-${app_name}-$(date +%Y%m%d-%H%M%S)" >> $GITHUB_ENV
        else
            echo "No matching Quay tag found for git tag $latest_git_tag for $app_name"
        fi
    else
        echo "Error fetching tags for $repo"
    fi
}

# Process all release files
for prod_slug in bfx/*; do
    if [[ -d "$prod_slug" ]]; then
        release_file="$prod_slug/release.json"
        if [[ -f "$release_file" ]]; then
            echo "Checking new releases for $(basename $prod_slug)..."
            process_release_file "$release_file"
        fi
    fi
    break
done