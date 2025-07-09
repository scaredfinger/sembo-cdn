#!/bin/bash

# Test runner script
set -e

echo "Running integration tests..."
busted tests/integration/ --verbose --pattern=test_
