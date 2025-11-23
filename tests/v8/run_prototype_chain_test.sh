#!/bin/bash
# V8 Prototype Chain Inheritance Test Runner

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPL="$PROJECT_ROOT/zig-out/bin/repl"
TEST_FILE="$SCRIPT_DIR/prototype_chain_test.js"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "=== V8 Prototype Chain Inheritance Test ==="
echo ""

# Check REPL exists
if [ ! -f "$REPL" ]; then
    echo -e "${RED}Error: REPL not found at $REPL${NC}"
    echo "Run 'zig build repl' first"
    exit 1
fi

# Run tests
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
echo "Total:  $TOTAL"
echo -e "${GREEN}Passed: $PASSED${NC}"
if [ "$FAILED" -gt 0 ]; then
    echo -e "${RED}Failed: $FAILED${NC}"
else
    echo "Failed: $FAILED"
fi
echo "Success Rate: ${PERCENTAGE}%"
echo ""

# Exit
if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
