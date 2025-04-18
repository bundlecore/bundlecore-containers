[![Dependabot Updates](https://github.com/bundlecore/bundlecore-containers/actions/workflows/dependabot/dependabot-updates/badge.svg)](https://github.com/bundlecore/bundlecore-containers/actions/workflows/dependabot/dependabot-updates)
[![Build and Push Docker Images](https://github.com/bundlecore/bundlecore-containers/actions/workflows/ci.yml/badge.svg)](https://github.com/bundlecore/bundlecore-containers/actions/workflows/ci.yml)

# Bundle Core Containers

This repository is the parent for all bundle core containers. It will contain multiple sub-repos following the git submodule pattern. See [this blog post](https://github.blog/open-source/git/working-with-submodules/) for more information.

Some more to read, https://gist.github.com/gitaarik/8735255

## Continuous Integration

The repository includes automated CI workflows that:

- Run daily at midnight to check for new releases
- Can be manually triggered via GitHub Actions
- Build and push Docker images to GitHub Container Registry
- Sign container images using build provenance attestation
- Automatically update version information via pull requests
- **Retag and sign BioContainer images from `biocontainers/<app>/release.json` to GitHub Container Registry (GHCR)**

### Container Versioning

Each container's version information is tracked in a `release.json` file within its directory. The file contains:
- `latest_version`: Current version of the container
- `repo_url`: Source repository URL
- Optional fields:
  - `dockerfile_location`: Custom Dockerfile path (defaults to "Dockerfile")
  - `repo_without_dockerfile`: Boolean indicating if Dockerfile should be copied from this repo

The CI workflow:
1. Checks each container's current version against the latest upstream GitHub release/tag
2. For outdated containers:
   - Builds and pushes new container images to ghcr.io
   - Creates a pull request to update the release.json file
3. Signs the published container images using build provenance attestation

**BioContainer Retagging Workflow:**
- Iterates through each app in `biocontainers/<app>/`
- Reads all images from `release.json`
- Retags and pushes each image to `ghcr.io/<org>/<app>:<tag>`
- Signs the retagged images using Cosign

Container images are published to `ghcr.io/<repository-name>/<container-name>:<version>`.


