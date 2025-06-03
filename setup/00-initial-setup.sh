#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Starting VPS Initial Setup...${NC}"

# Update system packages
echo -e "${YELLOW}Updating system packages...${NC}"
apt-get update && apt-get upgrade -y

# Set timezone
TIMEZONE=${1:-"UTC"}
echo -e "${YELLOW}Setting timezone to $TIMEZONE...${NC}"
timedatectl set-timezone $TIMEZONE

# Configure firewall
echo -e "${YELLOW}Configuring UFW firewall...${NC}"
ufw --force enable
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw reload

# Create management user if specified
if [ ! -z "$2" ]; then
    USERNAME=$2
    echo -e "${YELLOW}Creating management user: $USERNAME...${NC}"
    adduser --gecos "" --disabled-password $USERNAME
    usermod -aG sudo $USERNAME
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$USERNAME
    mkdir -p /home/$USERNAME/.ssh
    cp ~/.ssh/authorized_keys /home/$USERNAME/.ssh/
    chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
    chmod 700 /home/$USERNAME/.ssh
    chmod 600 /home/$USERNAME/.ssh/authorized_keys
fi

# Setup SSH security
echo -e "${YELLOW}Configuring SSH security...${NC}"
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/ssh_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/ssh_config
systemctl restart ssh

echo -e "${GREEN}Initial setup completed!${NC}"
