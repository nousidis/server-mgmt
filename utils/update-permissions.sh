#!/bin/bash

DOMAIN=$1

if [ -z "$DOMAIN" ]; then
    echo "Usage: $0 <domain>"
    exit 1
fi

# Get site info
if [ ! -f "/etc/vps-manager/configs/$DOMAIN.json" ]; then
    echo "Site configuration not found for $DOMAIN"
    exit 1
fi

USER=$(jq -r '.user' /etc/vps-manager/configs/$DOMAIN.json)
FRAMEWORK=$(jq -r '.framework' /etc/vps-manager/configs/$DOMAIN.json)

echo "Updating permissions for $DOMAIN..."

# Set ownership
chown -R $USER:$USER /var/www/$DOMAIN

# Set directory permissions
find /var/www/$DOMAIN -type d -exec chmod 755 {} \;

# Set file permissions
find /var/www/$DOMAIN -type f -exec chmod 644 {} \;

# Framework-specific permissions
case $FRAMEWORK in
    laravel)
        # Laravel storage and cache
        chmod -R 775 /var/www/$DOMAIN/storage
        chmod -R 775 /var/www/$DOMAIN/bootstrap/cache
        ;;
    nextjs|sveltekit)
        # Node.js build directories
        [ -d "/var/www/$DOMAIN/.next" ] && chmod -R 755 /var/www/$DOMAIN/.next
        [ -d "/var/www/$DOMAIN/build" ] && chmod -R 755 /var/www/$DOMAIN/build
        ;;
esac

# Log directory permissions
chown -R $USER:$USER /var/log/sites/$DOMAIN
chmod -R 755 /var/log/sites/$DOMAIN

echo "Permissions updated for $DOMAIN"
