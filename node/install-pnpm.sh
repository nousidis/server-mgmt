#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Installing pnpm...${NC}"

# Install pnpm
curl -fsSL https://get.pnpm.io/install.sh | sh -

# Add to system path
echo 'export PNPM_HOME="/root/.local/share/pnpm"' >> /etc/profile
echo 'export PATH="$PNPM_HOME:$PATH"' >> /etc/profile
source /etc/profile

# Configure pnpm store location
pnpm config set store-dir /var/cache/pnpm-store

echo -e "${GREEN}pnpm installed successfully!${NC}"
