#!/bin/bash
#
# WPT Serve Wrapper Script
#
# This script ensures all WPT server ports are cleared before starting
# the WPT test server. It kills any processes listening on the required ports.
#
# Usage: ./scripts/wpt-serve.sh [additional wpt serve arguments]
#

set -e

# WPT server ports (from tests/wpt/tools/serve/serve.py)
WPT_PORTS=(8000 8443 8444 9000)

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== WPT Server Startup ==="
echo ""

# Function to kill process on a specific port
kill_port() {
    local port=$1
    local pids=$(lsof -ti:$port 2>/dev/null || true)

    if [ -n "$pids" ]; then
        echo -e "${YELLOW}Killing process(es) on port $port: $pids${NC}"
        for pid in $pids; do
            kill -9 $pid 2>/dev/null || true
        done
        # Wait a moment for the port to be released
        sleep 0.5
        return 0
    fi
    return 1
}

# Clear all WPT ports
echo "Clearing WPT server ports..."
any_killed=false
for port in "${WPT_PORTS[@]}"; do
    if kill_port $port; then
        any_killed=true
    fi
done

if [ "$any_killed" = true ]; then
    echo -e "${GREEN}Ports cleared successfully${NC}"
    # Give OS time to fully release the ports
    sleep 1
else
    echo -e "${GREEN}All ports were already available${NC}"
fi

echo ""

# Change to the WPT directory
cd "$(dirname "$0")/../tests/wpt"

# Start WPT server
echo "Starting WPT server..."
echo "  HTTP:  http://web-platform.test:8000"
echo "  HTTPS: https://web-platform.test:8443"
echo "  HTTPS: https://web-platform.test:8444"
echo "  H2:    https://web-platform.test:9000"
echo ""

# Run WPT serve with any additional arguments passed to this script
python wpt serve "$@"
