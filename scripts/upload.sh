#!/bin/bash
###############################################################################
# Red Pitaya Upload Script
# =========================
# Uploads coincidence detector code to Red Pitaya via SCP
#
# Usage:
#   ./scripts/upload.sh <red-pitaya-ip>
#   ./scripts/upload.sh 192.168.1.100
#
# Default Red Pitaya credentials:
#   Username: root
#   Password: root
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

echo -e "${GREEN}Red Pitaya Coincidence Detector Upload${NC}"
echo "========================================"
echo "Target IP: $RP_IP"
echo "Destination: $RP_DEST"
echo ""

# Test connection
echo -e "${YELLOW}Testing connection to Red Pitaya...${NC}"
if ! ping -c 1 -W 2 $RP_IP > /dev/null 2>&1; then
    echo -e "${RED}Error: Cannot reach Red Pitaya at $RP_IP${NC}"
    echo "Please check:"
    echo "  - Red Pitaya is powered on"
    echo "  - Connected to same network"
    echo "  - IP address is correct"
    exit 1
fi
echo -e "${GREEN}✓ Red Pitaya is reachable${NC}"
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Check that source files exist
if [ ! -f "$PROJECT_ROOT/src/coincidence_detector.py" ]; then
    echo -e "${RED}Error: coincidence_detector.py not found${NC}"
    exit 1
fi

if [ ! -f "$PROJECT_ROOT/src/config.yaml" ]; then
    echo -e "${YELLOW}Warning: config.yaml not found, using defaults${NC}"
fi

echo -e "${YELLOW}Uploading files to Red Pitaya...${NC}"
echo "Note: Default password is 'root'"
echo ""

# Create destination directory on Red Pitaya
echo "Creating directory $RP_DEST on Red Pitaya..."
ssh ${RP_USER}@${RP_IP} "mkdir -p $RP_DEST"

# Upload source files
echo "Uploading Python script..."
scp "$PROJECT_ROOT/src/coincidence_detector.py" ${RP_USER}@${RP_IP}:${RP_DEST}/

# Upload config file if it exists
if [ -f "$PROJECT_ROOT/src/config.yaml" ]; then
    echo "Uploading configuration file..."
    scp "$PROJECT_ROOT/src/config.yaml" ${RP_USER}@${RP_IP}:${RP_DEST}/
fi

# Make script executable
echo "Setting executable permissions..."
ssh ${RP_USER}@${RP_IP} "chmod +x ${RP_DEST}/coincidence_detector.py"

# Check if PyYAML is installed
echo ""
echo -e "${YELLOW}Checking Python dependencies...${NC}"
if ssh ${RP_USER}@${RP_IP} "python3 -c 'import yaml' 2>/dev/null"; then
    echo -e "${GREEN}✓ PyYAML is installed${NC}"
else
    echo -e "${YELLOW}Warning: PyYAML not installed on Red Pitaya${NC}"
    echo "Installing PyYAML..."
    ssh ${RP_USER}@${RP_IP} "pip3 install PyYAML || echo 'Failed to install PyYAML automatically'"
fi

# Check if NumPy is installed
if ssh ${RP_USER}@${RP_IP} "python3 -c 'import numpy' 2>/dev/null"; then
    echo -e "${GREEN}✓ NumPy is installed${NC}"
else
    echo -e "${YELLOW}Warning: NumPy not installed on Red Pitaya${NC}"
    echo "NumPy is usually pre-installed on Red Pitaya OS"
fi

echo ""
echo -e "${GREEN}========================================"
echo "Upload complete!"
echo "========================================${NC}"
echo ""
echo "To run the detector:"
echo "  1. SSH to Red Pitaya:"
echo "     ssh ${RP_USER}@${RP_IP}"
echo ""
echo "  2. Navigate to directory:"
echo "     cd ${RP_DEST}"
echo ""
echo "  3. Edit config.yaml to set your Red Pitaya's IP address"
echo ""
echo "  4. Run the detector:"
echo "     python3 coincidence_detector.py"
echo ""
echo "Or use the run script:"
echo "  ./scripts/run_detector.sh $RP_IP"
echo ""
echo -e "${YELLOW}Important: Edit config.yaml and set the correct IP address!${NC}"
echo ""
