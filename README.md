[![Dependabot Updates](https://github.com/bundlecore/bundlecore-containers/actions/workflows/dependabot/dependabot-updates/badge.svg)](https://github.com/bundlecore/bundlecore-containers/actions/workflows/dependabot/dependabot-updates)
[![Build and Push Docker Images](https://github.com/bundlecore/bundlecore-containers/actions/workflows/ci.yml/badge.svg)](https://github.com/bundlecore/bundlecore-containers/actions/workflows/ci.yml)
[![Trivy Security Scan](https://github.com/bundlecore/bundlecore-containers/actions/workflows/trivy-security-scan.yaml/badge.svg)](https://github.com/bundlecore/bundlecore-containers/actions/workflows/trivy-security-scan.yaml)

# Bundle Core Containers

This repository is the parent for all bundle core containers, providing a comprehensive collection of bioinformatics tools packaged as Docker containers. It follows the git submodule pattern for managing multiple container projects. See [this blog post](https://github.blog/open-source/git/working-with-submodules/) for more information.

Additional reading: https://gist.github.com/gitaarik/8735255

## Repository Structure

```
bundlecore-containers/
├── bfx/                    # Bioinformatics tools (21+ tools)
│   ├── bcftools/
│   ├── bedtools/
│   ├── bowtie2/
│   └── ...
├── biocontainers/          # BioContainer integrations
├── docs/                   # Documentation
│   ├── trivy-security-scan-workflow.md
│   ├── workflow-diagram.md
│   └── quick-reference.md
├── .github/workflows/      # CI/CD workflows
│   ├── ci.yml
│   ├── trivy-security-scan.yaml
│   └── dependabot/
└── README.md
```

## Continuous Integration

The repository includes automated CI workflows that:

- **Build and Release**: Run daily at midnight to check for new releases
- **Container Management**: Build and push Docker images to GitHub Container Registry
- **Security**: Sign container images using build provenance attestation
- **Automation**: Automatically update version information via pull requests
- **BioContainer Integration**: Retag and sign BioContainer images from `biocontainers/<app>/release.json` to GitHub Container Registry (GHCR)
- **Security Scanning**: Monthly automated vulnerability scanning with Trivy

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

## Security Scanning

The repository implements automated security scanning using [Trivy](https://trivy.dev/) to identify vulnerabilities in container images.

### Trivy Security Scan Workflow

- **Schedule**: Runs automatically on the first Sunday of every month at 2:00 AM UTC
- **Scope**: Scans all container images in the `products/bfx/` namespace
- **Severity**: Focuses on CRITICAL and HIGH vulnerabilities
- **Performance**: Intelligent artifact reuse reduces scan time from 2-3 hours to ~30 seconds
- **Output**: Automated pull requests with comprehensive vulnerability reports

### Key Features

- 🔄 **Intelligent Artifact Reuse**: Reuses previous scan results for faster execution
- 🛡️ **Robust Recovery**: Checkpoint system allows resuming from interruptions
- 📊 **Comprehensive Reporting**: Organizes results by tool with detailed vulnerability information
- 🔧 **Smart Directory Matching**: Automatically maps container images to tool directories
- 📝 **Automated PR Management**: Creates or updates pull requests with scan results

### Quick Start

```bash
# Manual trigger
gh workflow run "Trivy Security Scan"

# Force fresh scan (ignore cached results)
gh workflow run "Trivy Security Scan" -f force_fresh_scan=true

# Debug mode
gh workflow run "Trivy Security Scan" -f debug_mode=true
```

### Documentation

- 📚 [Complete Workflow Documentation](docs/trivy-security-scan-workflow.md)
- 🔄 [Detailed Flow Diagrams](docs/workflow-diagram.md)
- 🚀 [Quick Reference Guide](docs/quick-reference.md)

## Getting Started

### Using Container Images

All container images are available from GitHub Container Registry:

```bash
# Pull a specific tool
docker pull ghcr.io/bundlecore/products/bfx/bcftools:1.19

# List available images
gh api /orgs/bundlecore/packages?package_type=container
```

### Adding New Tools

1. Create a new directory under `bfx/` for your tool
2. Add a `release.json` file with version information:
   ```json
   {
     "latest_version": "1.0.0",
     "repo_url": "https://github.com/example/tool"
   }
   ```
3. The CI workflow will automatically detect and build the new container

### Security Review Process

1. **Monthly Scans**: Automated Trivy scans create PRs with vulnerability reports
2. **Review Priority**: Focus on CRITICAL vulnerabilities first
3. **Update Planning**: Plan container updates for affected versions
4. **Merge Process**: Merge security PRs to update the baseline

## Contributing

We welcome contributions! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Ensure all CI checks pass
5. Submit a pull request

### Development Workflow

- **Container Updates**: Automated via CI when upstream releases are detected
- **Security Patches**: Monthly vulnerability scanning with automated reporting
- **Quality Assurance**: All images are signed and include provenance attestation

## Support

- **Issues**: Report bugs or request features via GitHub Issues
- **Security**: Security vulnerabilities are tracked via automated Trivy scans
- **Documentation**: Comprehensive guides available in the `docs/` directory

## License

This project is licensed under the terms specified in individual container directories.


