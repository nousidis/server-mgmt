#!/bin/bash

# VPS Manager Core - Handles sudo requirements automatically

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    # Re-run the entire script with sudo
    exec sudo "$0" "$@"
fi

# Now we're guaranteed to be running as root
# Source the actual vps-manager script
source /usr/local/bin/vps-manager.sh "$@"
