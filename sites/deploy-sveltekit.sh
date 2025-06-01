#!/bin/bash

DOMAIN=$1
GIT_REPO=$2

if [ -z "$DOMAIN" ]; then
    echo "Usage: $0 <domain> [git_repo]"
    exit 1
fi

# Get site info
if [ ! -f "/etc/vps-manager/configs/$DOMAIN.json" ]; then
    echo "Site configuration not found for $DOMAIN"
    exit 1
fi

USER=$(jq -r '.user' /etc/vps-manager/configs/$DOMAIN.json)
PORT=$(jq -r '.port' /etc/vps-manager/configs/$DOMAIN.json)

# Clone or pull repository
if [ ! -z "$GIT_REPO" ]; then
    if [ ! -d "/var/www/$DOMAIN/.git" ]; then
        su - $USER -c "git clone $GIT_REPO /var/www/$DOMAIN"
    else
        su - $USER -c "cd /var/www/$DOMAIN && git pull"
    fi
fi

# Deploy SvelteKit
su - $USER -c "
    cd /var/www/$DOMAIN
    
    # Install dependencies
    export PNPM_HOME=\"\$HOME/.local/share/pnpm\"
    export PATH=\"\$PNPM_HOME:\$PATH\"
    pnpm install
    
    # Build application
    pnpm build
    
    # Setup PM2 process
    pm2 delete $DOMAIN 2>/dev/null || true
    PORT=$PORT pm2 start build/index.js --name $DOMAIN
    pm2 save
"

echo "SvelteKit application deployed for $DOMAIN"
