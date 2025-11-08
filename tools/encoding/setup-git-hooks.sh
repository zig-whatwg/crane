#!/bin/bash
#
# Setup Git Hooks
#
# This script installs git hooks for the zig-whatwg/encoding repository.
# It creates a pre-commit hook that ensures code quality before commits.
#
# Usage: ./scripts/setup-git-hooks.sh

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "🔧 Setting up Git hooks for zig-whatwg/encoding..."
echo ""

# Check if .git directory exists
if [ ! -d ".git" ]; then
    echo "Error: .git directory not found!"
    echo "Please run this script from the repository root."
    exit 1
fi

# Create hooks directory if it doesn't exist
mkdir -p .git/hooks

# Install pre-commit hook
echo -n "→ Installing pre-commit hook... "
cp scripts/pre-commit.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
echo -e "${GREEN}✓${NC}"

# Test the hook
echo -n "→ Testing hook installation... "
if [ -x .git/hooks/pre-commit ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    echo "Error: Hook is not executable!"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Git hooks installed successfully!${NC}"
echo ""
echo "The pre-commit hook will now run automatically on every commit."
echo ""
echo "It checks:"
echo "  • Code formatting (zig fmt --check)"
echo "  • Build success (zig build)"
echo "  • Test success (zig build test)"
echo ""
echo -e "${YELLOW}Note:${NC} To bypass the hook in emergencies, use:"
echo "  git commit --no-verify"
echo ""
