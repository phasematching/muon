#!/bin/bash
###############################################################################
# Red Pitaya Detector Runner
# ===========================
# Runs the coincidence detector on Red Pitaya via SSH
#
# Usage:
#   ./scripts/run_detector.sh <red-pitaya-ip>
#   ./scripts/run_detector.sh 192.168.1.100
#
# This script connects to Red Pitaya and runs the coincidence detector.
# Press Ctrl+C to stop the detector.
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if IP address is provided
if [ $# -eq 0 ]; then
    echo -e "${RED}Error: Red Pitaya IP address required${NC}"
    echo "Usage: $0 <red-pitaya-ip>"
    echo "Example: $0 192.168.1.100"
    exit 1
fi

RP_IP=$1
RP_USER="root"
RP_DEST="/root/muon"

echo -e "${GREEN}Red Pitaya Coincidence Detector${NC}"
echo "========================================"
echo "Connecting to: $RP_IP"
echo ""

# Test connection
if ! ping -c 1 -W 2 $RP_IP > /dev/null 2>&1; then
    echo -e "${RED}Error: Cannot reach Red Pitaya at $RP_IP${NC}"
    exit 1
fi

echo -e "${YELLOW}Starting detector...${NC}"
echo "Press Ctrl+C to stop"
echo ""

# Run the detector via SSH
# The -t flag allocates a pseudo-terminal for proper Ctrl+C handling
ssh -t ${RP_USER}@${RP_IP} "cd ${RP_DEST} && python3 coincidence_detector.py"
