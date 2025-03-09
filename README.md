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
- Sign container images for security
- Automatically update version tags

### Container Versioning

Each container's version is tracked in a `release.tag` file within its directory. The CI workflow:

1. Checks the current version against the latest upstream release
2. Builds and pushes new container images when updates are available
3. Updates the `release.tag` file via pull request when new versions are published

Container images are published to `ghcr.io` with tags matching the upstream release versions.

