#!/bin/bash
set -euo pipefail

DOMAIN=$1
NODE_VERSION=$2
USER=$3

if [ -z "$DOMAIN" ] || [ -z "$NODE_VERSION" ] || [ -z "$USER" ]; then
    echo "Usage: $0 <domain> <node_version> <user>"
    exit 1
fi

# Switch to user and install Node version
su - $USER -c "
    export PNPM_HOME=\"\$HOME/.local/share/pnpm\"
    export PATH=\"\$PNPM_HOME:\$PATH\"
    cd /var/www/$DOMAIN
    pnpm env use --global $NODE_VERSION
    echo $NODE_VERSION > .nvmrc
"

echo "Node.js $NODE_VERSION configured for $DOMAIN"
