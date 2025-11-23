#!/bin/bash
# V8 WebIDL Bindings Test Runner

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPL="$PROJECT_ROOT/zig-out/bin/repl"
TEST_FILE="$SCRIPT_DIR/bindings_test.js"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== V8 WebIDL Bindings Test Suite ==="
echo ""

# Check if REPL exists
if [ ! -f "$REPL" ]; then
    echo -e "${RED}Error: REPL not found at $REPL${NC}"
    echo "Run 'zig build' first to build the REPL"
    exit 1
fi

# Check if test file exists
if [ ! -f "$TEST_FILE" ]; then
    echo -e "${RED}Error: Test file not found at $TEST_FILE${NC}"
    exit 1
fi

# Run tests and capture output
echo "Running tests..."
OUTPUT=$("$REPL" < "$TEST_FILE" 2>&1)

# Count results
TOTAL=$(echo "$OUTPUT" | grep -E "^(true|false)" | wc -l | tr -d ' ')
PASSED=$(echo "$OUTPUT" | grep "^true" | wc -l | tr -d ' ')
FAILED=$(echo "$OUTPUT" | grep "^false" | wc -l | tr -d ' ')

# Calculate percentage
if [ "$TOTAL" -gt 0 ]; then
    PERCENTAGE=$(awk "BEGIN {printf \"%.1f\", ($PASSED / $TOTAL) * 100}")
else
    PERCENTAGE="0.0"
fi

# Print summary
echo ""
echo "=== Test Results ==="
echo -e "Total:  $TOTAL"
echo -e "${GREEN}Passed: $PASSED${NC}"
if [ "$FAILED" -gt 0 ]; then
    echo -e "${RED}Failed: $FAILED${NC}"
else
    echo -e "Failed: $FAILED"
fi
echo -e "Success Rate: ${PERCENTAGE}%"
echo ""

# Show which tests failed if any
if [ "$FAILED" -gt 0 ]; then
    echo -e "${YELLOW}=== Failed Tests ===${NC}"
    
    # Extract line numbers where false appears
    echo "$OUTPUT" | awk '/^>>>/ {line=$0; next} /^false/ {print line}' | sed 's/>>> //'
    echo ""
fi

# Exit with appropriate code
if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
