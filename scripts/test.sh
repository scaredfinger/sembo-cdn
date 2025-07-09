#!/bin/bash

# Test runner script
set -e

busted tests/unit/ --verbose --pattern=test_

echo "All tests completed!"
