# Demo: Test Execution for Trivy Security Scan

This document demonstrates how to execute the test suite for the Trivy Security Scan workflow.

## Test Structure Created

The following test structure has been implemented:

```
tests/trivy-security-scan/
├── README.md                           # Test documentation
├── fixtures/                           # Test data and mock responses
│   └── .gitkeep
├── unit/                              # Unit tests
│   ├── test-image-discovery.sh        # Tests GitHub API integration
│   └── test-sarif-validation.sh       # Tests SARIF format validation
├── integration/                       # Integration tests
│   ├── test-workflow-execution.sh     # Tests end-to-end workflow
│   └── test-github-security-integration.sh # Tests GitHub Security tab
└── scripts/                          # Test utilities
    ├── run-tests.sh                   # Main test runner
    └── validate-sarif.sh              # SARIF validation utility
```

## Test Coverage

### Unit Tests

1. **Image Discovery API Integration** (`test-image-discovery.sh`)
   - Package filtering logic
   - Image URL generation
   - Tag extraction from API responses
   - URL encoding for package names
   - Image URL validation regex
   - Error handling for invalid JSON
   - Empty response handling
   - Complete image discovery simulation

2. **SARIF Output Format Validation** (`test-sarif-validation.sh`)
   - Basic SARIF JSON structure validation
   - SARIF schema version validation
   - Tool driver information validation
   - Vulnerability results structure
   - Security severity levels
   - Image location validation
   - Invalid SARIF file handling
   - Empty results handling
   - SARIF aggregation and summary

### Integration Tests

1. **Workflow Execution** (`test-workflow-execution.sh`)
   - Workflow environment validation
   - Image discovery step simulation
   - Trivy scanning with sample images
   - Error handling and retry logic
   - SARIF output validation
   - Workflow timeout handling
   - Results aggregation

2. **GitHub Security Integration** (`test-github-security-integration.sh`)
   - SARIF file preparation for upload
   - GitHub CLI authentication
   - SARIF upload simulation
   - Security alerts creation verification
   - Multiple SARIF files upload
   - Error handling for invalid SARIF
   - SARIF metadata validation
   - Complete GitHub Security workflow

## Running Tests

### All Tests
```bash
./tests/trivy-security-scan/scripts/run-tests.sh
```

### Unit Tests Only
```bash
./tests/trivy-security-scan/scripts/run-tests.sh unit
```

### Integration Tests Only
```bash
./tests/trivy-security-scan/scripts/run-tests.sh integration
```

### With Verbose Output
```bash
./tests/trivy-security-scan/scripts/run-tests.sh -v unit
```

### SARIF Validation
```bash
./tests/trivy-security-scan/scripts/validate-sarif.sh results.sarif
```

## Requirements Coverage

The test suite covers the following requirements from the specification:

### Requirement 3.2 (GitHub Security tab integration)
- ✅ SARIF upload functionality testing
- ✅ Security alerts creation verification
- ✅ GitHub CLI integration testing
- ✅ Error handling for invalid SARIF files

### Requirement 4.3 (Error handling and reliability)
- ✅ API error handling and retry logic testing
- ✅ Individual image scan failure handling
- ✅ Timeout handling validation
- ✅ Invalid input validation testing

## Test Features

### Mock Implementations
- Mock GitHub API responses for package discovery
- Mock Trivy executable for scan simulation
- Mock GitHub CLI for Security tab integration
- Mock SARIF files with various vulnerability scenarios

### Error Scenarios
- Invalid JSON responses from GitHub API
- Network timeouts and failures
- Missing or inaccessible container images
- Invalid SARIF file formats
- Authentication failures

### Validation Checks
- JSON syntax validation
- SARIF schema compliance
- GitHub Security integration requirements
- Image URL format validation
- Security severity validation

## Example Test Output

```
Trivy Security Scan Test Runner
===============================
Suite: unit
Verbose: false
Parallel: false
Coverage: false

[INFO] Checking test environment...
[INFO] ✓ Environment check completed

Running Unit Tests
==================

[INFO] Running: Image Discovery API Integration
[INFO] ✓ PASSED: Image Discovery API Integration (2s, 8 tests)

[INFO] Running: SARIF Output Format and Content Validation  
[INFO] ✓ PASSED: SARIF Output Format and Content Validation (1s, 9 tests)

[INFO] Unit Tests Summary: 2 passed, 0 failed

Test Execution Summary
======================
Suite: unit
Total Tests: 17
Passed: 17
Failed: 0
Success Rate: 100%

[INFO] 🎉 All tests passed!
```

## Notes

- Tests use mock implementations to avoid external dependencies
- All test scripts are executable and self-contained
- Test fixtures are generated dynamically during test execution
- The test runner provides detailed error reporting and logging
- SARIF validation utility can be used independently for file validation