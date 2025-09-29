# Trivy Security Scan Tests

This directory contains test cases and validation scripts for the Trivy Security Scan workflow.

## Test Structure

- `unit/` - Unit tests for individual components
- `integration/` - Integration tests for workflow execution
- `fixtures/` - Test data and mock responses
- `scripts/` - Test execution and validation scripts

## Running Tests

```bash
# Run all tests
./scripts/run-tests.sh

# Run specific test suite
./scripts/run-tests.sh unit
./scripts/run-tests.sh integration

# Validate SARIF output
./scripts/validate-sarif.sh path/to/sarif/file.sarif
```

## Test Requirements Coverage

- **Requirement 3.2**: GitHub Security tab integration validation
- **Requirement 4.3**: Error handling and reliability testing