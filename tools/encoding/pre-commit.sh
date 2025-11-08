#!/bin/bash
#
# Pre-commit hook for zig-whatwg/encoding
#
# This hook runs before every commit to ensure code quality.
# It checks:
# 1. Code formatting (zig fmt --check)
# 2. Build success (zig build)
# 3. Test success (zig build test)
#
# To install: ./scripts/setup-git-hooks.sh
# To bypass: git commit --no-verify (NOT recommended)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo "🔍 Running pre-commit checks..."
echo ""

# Check 1: Code formatting
echo -n "→ Checking code formatting... "
if zig fmt --check src/ tests/ > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    echo ""
    echo -e "${RED}❌ Formatting check failed!${NC}"
    echo ""
    echo "The following files need formatting:"
    zig fmt --check src/ tests/
    echo ""
    echo "To fix, run:"
    echo -e "${YELLOW}  zig fmt src/ tests/${NC}"
    echo "  git add -u"
    echo "  git commit"
    echo ""
    exit 1
fi

# Check 2: Build
echo -n "→ Building project... "
if zig build > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    echo ""
    echo -e "${RED}❌ Build failed!${NC}"
    echo ""
    echo "Build output:"
    zig build
    echo ""
    exit 1
fi

# Check 3: Tests
echo -n "→ Running tests... "
if zig build test --summary all > /tmp/test-output.txt 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    echo ""
    echo -e "${RED}❌ Tests failed!${NC}"
    echo ""
    echo "Test output:"
    cat /tmp/test-output.txt
    echo ""
    exit 1
fi

echo ""
echo -e "${GREEN}✅ All pre-commit checks passed!${NC}"
echo ""

exit 0
