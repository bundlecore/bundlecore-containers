# Trivy Security Scan - Quick Reference Guide

## 🚀 Quick Start

### Automatic Execution
- **When**: First Sunday of every month at 2:00 AM UTC
- **Duration**: ~30 seconds (with artifact reuse) or 2-3 hours (fresh scan)
- **Output**: Smart PR creation only for meaningful changes, comprehensive audit trail always

### Manual Execution
```bash
# Basic manual run
gh workflow run "Trivy Security Scan"

# Force fresh scan (ignore cached results)
gh workflow run "Trivy Security Scan" -f force_fresh_scan=true

# Debug mode (detailed logging)
gh workflow run "Trivy Security Scan" -f debug_mode=true
```

## 📊 Understanding Results

### Smart PR Examples

#### CRITICAL Vulnerabilities Detected
```
🚨 CRITICAL vulnerabilities detected in 3 tools - 2025-01-05
├── bfx/bcftools/trivy-scan-results.json (1 CRITICAL)
├── bfx/bedtools/trivy-scan-results.json (2 CRITICAL)
├── bfx/bowtie2/trivy-scan-results.json (1 HIGH)
└── .github/security-scan-audit.json (updated)

Labels: critical, urgent, vulnerabilities, security, automated
Assigned: @gkr0110
```

#### New Versions Scanned
```
📦 New container versions scanned - 2025-01-05
├── bfx/bowtie2/trivy-scan-results.json (added v2.5.1)
├── bfx/gatk4/trivy-scan-results.json (added v4.5.0)
└── .github/security-scan-audit.json (updated)

Labels: new-versions, security, automated
Assigned: @gkr0110
```

#### No PR Created (Metadata Only)
```
No PR created - only metadata changes detected
└── .github/security-scan-audit.json (scan recorded)

Audit trail updated, compliance maintained
```

### JSON Result Format
```json
{
  "tool": "bcftools",
  "scan_timestamp": "2025-01-05T10:30:00Z",
  "workflow_run_id": "12345",
  "versions": {
    "1.19": {
      "image": "ghcr.io/bundlecore/products/bfx/bcftools:1.19",
      "vulnerabilities": [...],
      "vulnerability_count": 5
    }
  },
  "summary": {
    "total_versions_scanned": 3,
    "total_vulnerabilities": 12
  }
}
```

## 🔧 Common Operations

### Check Workflow Status
```bash
# List recent runs
gh run list --workflow="Trivy Security Scan"

# View specific run
gh run view <run-id>

# Download artifacts
gh run download <run-id>
```

### Handle Failed Runs
```bash
# Resume from progress (default behavior)
gh workflow run "Trivy Security Scan" -f resume_from_progress=true

# Start fresh if resume fails
gh workflow run "Trivy Security Scan" -f force_fresh_scan=true
```

### Review Security Results
1. **Check PR**: Review the auto-created pull request
2. **Priority**: Focus on CRITICAL vulnerabilities first
3. **Plan Updates**: Identify which container versions need updates
4. **Merge PR**: Update security baseline after review

## 🎯 Key Metrics

### Performance Indicators
- **Fresh Scan**: 2-3 hours, 63 images
- **Artifact Reuse**: 30 seconds, 0 new scans
- **Partial Resume**: Variable, depends on progress
- **Success Rate**: >95% with retry logic

### Artifact Storage
- **Raw Results**: 30 days retention
- **Organized Results**: 90 days retention
- **Storage Size**: ~50MB per complete scan

## 🚨 Troubleshooting

### Common Issues & Solutions

| Issue | Symptom | Solution |
|-------|---------|----------|
| No images found | `⚠ No container images found` | Check ghcr.io permissions and image naming |
| Scan timeouts | `✗ Scan failed - timeout` | Images too large, check network connectivity |
| Directory mismatch | `✗ No matching directory found` | Verify bfx/ directory structure |
| Branch conflicts | `✗ Failed to push branch` | Workflow handles automatically with force-push |
| PR exists | `⚠ Pull request already exists` | Workflow updates existing PR intelligently |
| No PR created | `⏭ No PR creation needed` | Normal behavior - only metadata changed |
| Change detection failed | `✗ Failed to analyze changes` | Check JSON format and git history |

### Debug Commands
```bash
# Enable debug mode
gh workflow run "Trivy Security Scan" -f debug_mode=true

# Check artifacts from recent run
gh run download <run-id> --name trivy-scan-results

# View workflow logs
gh run view <run-id> --log
```

## 📋 Maintenance Tasks

### Monthly Review
- [ ] Check PRs for new CRITICAL vulnerabilities (if any created)
- [ ] Review audit trail in `.github/security-scan-audit.json`
- [ ] Verify scan coverage (all tools included?)
- [ ] Update container images with security patches
- [ ] Confirm @gkr0110 assignment is working

### Quarterly Review
- [ ] Review workflow performance metrics from audit trail
- [ ] Analyze PR creation patterns (noise vs signal ratio)
- [ ] Update Trivy version if needed
- [ ] Check for new tools to include in scanning
- [ ] Validate directory structure matches container naming
- [ ] Review change detection accuracy

### Audit Trail Monitoring
- [ ] Verify scans are running monthly (check `last_scan_timestamp`)
- [ ] Review `scan_history` for success rates
- [ ] Monitor `tools_last_scanned` for coverage gaps
- [ ] Check `changes_detected` vs `pr_created` ratios

## 🧠 Intelligent Features

### Change Detection Logic
```bash
# PR Created For:
✅ New CRITICAL vulnerabilities
✅ New HIGH vulnerabilities  
✅ Vulnerabilities resolved
✅ New container versions
✅ Removed container versions

# PR NOT Created For:
❌ Only timestamp changes
❌ Only workflow run ID changes
❌ Identical vulnerability data
❌ No version changes
```

### Smart PR Titles
- `🚨 CRITICAL vulnerabilities detected in 3 tools`
- `⚠️ HIGH vulnerabilities detected in 2 tools`
- `📦 New container versions scanned: bowtie2 v2.5.1`
- `✅ Vulnerabilities resolved in 4 tools`
- `🗑️ Container versions removed`

### Intelligent Labels
- **Severity**: `critical`, `urgent`, `high-priority`
- **Change Type**: `vulnerabilities`, `new-versions`
- **Standard**: `security`, `automated`, `trivy-scan`

### Audit Trail Benefits
- **Compliance**: Proof of regular scanning
- **History**: Complete scan activity record
- **Metrics**: Success rates and performance data
- **Coverage**: Tool-level scan verification

## 🔐 Security Best Practices

### Vulnerability Prioritization
1. **CRITICAL**: Immediate action required
2. **HIGH**: Plan updates within 30 days
3. **MEDIUM/LOW**: Not scanned (reduces noise)

### Container Updates
1. Check for updated base images
2. Rebuild containers with latest patches
3. Test updated containers
4. Deploy to production
5. Re-run security scan to verify fixes

## 📞 Support

### Getting Help
- **Workflow Issues**: Check GitHub Actions logs
- **Security Questions**: Review vulnerability details in JSON files
- **Tool Coverage**: Verify container images follow `products/bfx/*` pattern

### Useful Links
- [Trivy Documentation](https://trivy.dev/)
- [Vulnerability Database](https://github.com/aquasecurity/trivy-db)
- [GitHub Actions Docs](https://docs.github.com/en/actions)

---

*This quick reference covers the most common operations and troubleshooting scenarios for the Trivy Security Scan workflow.*