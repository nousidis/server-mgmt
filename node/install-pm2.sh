#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Installing PM2...${NC}"

# Install PM2 globally
pnpm add -g pm2

# Setup PM2 startup script
pm2 startup systemd -u root --hp /root
systemctl enable pm2-root

# Configure PM2 log rotation
pm2 install pm2-logrotate
pm2 set pm2-logrotate:max_size 10M
pm2 set pm2-logrotate:retain 7
pm2 set pm2-logrotate:compress true

echo -e "${GREEN}PM2 installed and configured!${NC}"
