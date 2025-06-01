#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Installing system dependencies...${NC}"

# Install build essentials
apt-get install -y build-essential software-properties-common

# Install common tools
apt-get install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    zip \
    unzip \
    ncdu \
    tree \
    jq

# Install supervisor
apt-get install -y supervisor
systemctl enable supervisor
systemctl start supervisor

# Install certbot
apt-get install -y certbot python3-certbot-nginx

# Install fail2ban
apt-get install -y fail2ban
systemctl enable fail2ban
systemctl start fail2ban

echo -e "${GREEN}Dependencies installed successfully!${NC}"
