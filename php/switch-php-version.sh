#!/bin/bash

DOMAIN=$1
NEW_PHP_VERSION=$2

if [ -z "$DOMAIN" ] || [ -z "$NEW_PHP_VERSION" ]; then
    echo "Usage: $0 <domain> <new_php_version>"
    exit 1
fi

# Find current PHP version
CURRENT_PHP_VERSION=$(ls /etc/php/*/fpm/pool.d/$DOMAIN.conf 2>/dev/null | grep -oP '(?<=php/)[0-9.]+(?=/fpm)')

if [ -z "$CURRENT_PHP_VERSION" ]; then
    echo "No PHP pool found for domain: $DOMAIN"
    exit 1
fi

# Get user from current pool
USER=$(grep "^user = " /etc/php/$CURRENT_PHP_VERSION/fpm/pool.d/$DOMAIN.conf | cut -d' ' -f3)

# Remove old pool
rm -f /etc/php/$CURRENT_PHP_VERSION/fpm/pool.d/$DOMAIN.conf
systemctl reload php$CURRENT_PHP_VERSION-fpm

# Create new pool
/usr/local/bin/create-php-pool.sh $DOMAIN $NEW_PHP_VERSION $USER

# Update nginx config
NGINX_CONFIG="/etc/nginx/sites-available/$DOMAIN"
if [ -f "$NGINX_CONFIG" ]; then
    sed -i "s/php$CURRENT_PHP_VERSION-fpm/php$NEW_PHP_VERSION-fpm/g" $NGINX_CONFIG
    nginx -t && systemctl reload nginx
fi

echo "Switched $DOMAIN from PHP $CURRENT_PHP_VERSION to PHP $NEW_PHP_VERSION"
