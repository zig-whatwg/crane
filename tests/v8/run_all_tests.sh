#!/bin/bash
# V8 WebIDL Bindings Comprehensive Test Runner
# Runs both basic and advanced test suites

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPL="$PROJECT_ROOT/zig-out/bin/repl"
BASIC_TEST="$SCRIPT_DIR/bindings_test.js"
ADVANCED_TEST="$SCRIPT_DIR/bindings_advanced_test.js"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== V8 WebIDL Bindings Comprehensive Test Suite ===${NC}"
echo ""

# Check if REPL exists
if [ ! -f "$REPL" ]; then
    echo -e "${RED}Error: REPL not found at $REPL${NC}"
    echo "Run 'zig build' first to build the REPL"
    exit 1
fi

# Function to run a test file
run_test_file() {
    local test_file=$1
    local test_name=$2
    
    if [ ! -f "$test_file" ]; then
        echo -e "${RED}Error: Test file not found at $test_file${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Running $test_name...${NC}"
    OUTPUT=$("$REPL" < "$test_file" 2>&1)
    
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
    
    # Print results
    echo -e "  Total:  $TOTAL"
    echo -e "  ${GREEN}Passed: $PASSED${NC}"
    if [ "$FAILED" -gt 0 ]; then
        echo -e "  ${RED}Failed: $FAILED${NC}"
    else
        echo -e "  Failed: $FAILED"
    fi
    echo -e "  Success Rate: ${PERCENTAGE}%"
    echo ""
    
    # Show which tests failed if any
    if [ "$FAILED" -gt 0 ]; then
        echo -e "${YELLOW}=== Failed Tests in $test_name ===${NC}"
        echo "$OUTPUT" | awk '/^>>>/ {line=$0; next} /^false/ {print line}' | sed 's/>>> //'
        echo ""
    fi
    
    # Return counts for aggregation
    echo "$TOTAL $PASSED $FAILED"
}

# Run basic tests
BASIC_RESULTS=$(run_test_file "$BASIC_TEST" "Basic Tests (Prototype Chain & Methods)")
BASIC_TOTAL=$(echo $BASIC_RESULTS | awk '{print $1}')
BASIC_PASSED=$(echo $BASIC_RESULTS | awk '{print $2}')
BASIC_FAILED=$(echo $BASIC_RESULTS | awk '{print $3}')

# Run advanced tests
ADVANCED_RESULTS=$(run_test_file "$ADVANCED_TEST" "Advanced Tests (Constants, Mixins, Metadata, etc.)")
ADVANCED_TOTAL=$(echo $ADVANCED_RESULTS | awk '{print $1}')
ADVANCED_PASSED=$(echo $ADVANCED_RESULTS | awk '{print $2}')
ADVANCED_FAILED=$(echo $ADVANCED_RESULTS | awk '{print $3}')

# Aggregate results
TOTAL_TESTS=$((BASIC_TOTAL + ADVANCED_TOTAL))
TOTAL_PASSED=$((BASIC_PASSED + ADVANCED_PASSED))
TOTAL_FAILED=$((BASIC_FAILED + ADVANCED_FAILED))

if [ "$TOTAL_TESTS" -gt 0 ]; then
    TOTAL_PERCENTAGE=$(awk "BEGIN {printf \"%.1f\", ($TOTAL_PASSED / $TOTAL_TESTS) * 100}")
else
    TOTAL_PERCENTAGE="0.0"
fi

# Print summary
echo ""
echo -e "${BLUE}=== Overall Summary ===${NC}"
echo -e "Total Tests:  $TOTAL_TESTS"
echo -e "${GREEN}Passed:       $TOTAL_PASSED${NC}"
if [ "$TOTAL_FAILED" -gt 0 ]; then
    echo -e "${RED}Failed:       $TOTAL_FAILED${NC}"
else
    echo -e "Failed:       $TOTAL_FAILED"
fi
echo -e "Success Rate: ${TOTAL_PERCENTAGE}%"
echo ""

# Exit with appropriate code
if [ "$TOTAL_FAILED" -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
