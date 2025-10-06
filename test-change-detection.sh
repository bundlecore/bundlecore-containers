#!/bin/bash

# Test script to verify the change detection logic
echo "Testing change detection logic..."

# Create test JSON files
mkdir -p test-bfx/bcftools

# Old content (simulating main branch)
cat > old.json << 'EOF'
{
  "tool": "bcftools",
  "scan_timestamp": "2025-01-05T10:00:00Z",
  "workflow_run_id": "12345",
  "versions": {
    "1.19": {
      "image": "ghcr.io/bundlecore/products/bfx/bcftools:1.19",
      "vulnerabilities": [
        {"Severity": "HIGH", "VulnerabilityID": "CVE-2024-1001"}
      ],
      "vulnerability_count": 1
    }
  }
}
EOF

# New content (simulating current scan)
cat > new.json << 'EOF'
{
  "tool": "bcftools",
  "scan_timestamp": "2025-01-06T10:00:00Z",
  "workflow_run_id": "67890",
  "versions": {
    "1.19": {
      "image": "ghcr.io/bundlecore/products/bfx/bcftools:1.19",
      "vulnerabilities": [
        {"Severity": "HIGH", "VulnerabilityID": "CVE-2024-1001"}
      ],
      "vulnerability_count": 1
    }
  }
}
EOF

# Function to normalize JSON for comparison (exclude metadata)
normalize_for_comparison() {
  local file="$1"
  jq -S 'del(.scan_timestamp, .workflow_run_id) | 
         .versions | to_entries | 
         map({
           key: .key, 
           value: {
             image: .value.image,
             vulnerabilities: (.value.vulnerabilities // []),
             vulnerability_count: (.value.vulnerability_count // 0)
           }
         }) | 
         from_entries' "$file" 2>/dev/null || echo "{}"
}

# Test the comparison
OLD_NORMALIZED=$(normalize_for_comparison old.json)
NEW_NORMALIZED=$(normalize_for_comparison new.json)

echo "Old normalized:"
echo "$OLD_NORMALIZED"
echo ""
echo "New normalized:"
echo "$NEW_NORMALIZED"
echo ""

if [ "$OLD_NORMALIZED" = "$NEW_NORMALIZED" ]; then
  echo "✅ TEST PASSED: No meaningful changes detected (metadata only)"
else
  echo "❌ TEST FAILED: Changes detected when there should be none"
fi

# Test with actual changes
cat > new_with_changes.json << 'EOF'
{
  "tool": "bcftools",
  "scan_timestamp": "2025-01-06T10:00:00Z",
  "workflow_run_id": "67890",
  "versions": {
    "1.19": {
      "image": "ghcr.io/bundlecore/products/bfx/bcftools:1.19",
      "vulnerabilities": [
        {"Severity": "HIGH", "VulnerabilityID": "CVE-2024-1001"},
        {"Severity": "CRITICAL", "VulnerabilityID": "CVE-2024-2002"}
      ],
      "vulnerability_count": 2
    }
  }
}
EOF

CHANGED_NORMALIZED=$(normalize_for_comparison new_with_changes.json)

echo ""
echo "Changed normalized:"
echo "$CHANGED_NORMALIZED"
echo ""

if [ "$OLD_NORMALIZED" != "$CHANGED_NORMALIZED" ]; then
  echo "✅ TEST PASSED: Changes correctly detected"
else
  echo "❌ TEST FAILED: Changes not detected when they should be"
fi

# Cleanup
rm -f old.json new.json new_with_changes.json
rm -rf test-bfx

echo ""
echo "Change detection logic test completed!"