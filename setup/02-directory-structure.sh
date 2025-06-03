#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Creating directory structure...${NC}"

# Create web directories
mkdir -p /var/www
mkdir -p /var/backups/sites
mkdir -p /var/log/sites

# Create nginx directories
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled
mkdir -p /etc/nginx/ssl

# Create script config directory
mkdir -p /etc/vps-manager
mkdir -p /etc/vps-manager/configs

# Set permissions
chmod 755 /var/www
chmod 755 /var/backups
chmod 755 /var/log/sites

echo -e "${GREEN}Directory structure created!${NC}"
