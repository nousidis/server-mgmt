#!/bin/bash
set -euo pipefail

DOMAIN=$1
FRAMEWORK=$2
PHP_VERSION=$3
PORT=$4

if [ -z "$DOMAIN" ] || [ -z "$FRAMEWORK" ]; then
    echo "Usage: $0 <domain> <framework> [php_version] [port]"
    echo "Frameworks: laravel, php, nextjs, sveltekit, static"
    exit 1
fi

TEMPLATE_DIR="/usr/local/bin/nginx/templates"
NGINX_AVAILABLE="/etc/nginx/sites-available/$DOMAIN"
NGINX_ENABLED="/etc/nginx/sites-enabled/$DOMAIN"

# Select template based on framework
case $FRAMEWORK in
    laravel)
        TEMPLATE="$TEMPLATE_DIR/laravel.conf.template"
        ;;
    php)
        TEMPLATE="$TEMPLATE_DIR/php-generic.conf.template"
        ;;
    nextjs)
        TEMPLATE="$TEMPLATE_DIR/nextjs.conf.template"
        ;;
    sveltekit)
        TEMPLATE="$TEMPLATE_DIR/sveltekit.conf.template"
        ;;
    static)
        TEMPLATE="$TEMPLATE_DIR/static.conf.template"
        ;;
    *)
        echo "Unknown framework: $FRAMEWORK"
        exit 1
        ;;
esac

# Copy template and replace variables
cp $TEMPLATE $NGINX_AVAILABLE
sed -i "s/{{DOMAIN}}/$DOMAIN/g" $NGINX_AVAILABLE
sed -i "s/{{PHP_VERSION}}/$PHP_VERSION/g" $NGINX_AVAILABLE
sed -i "s/{{PORT}}/$PORT/g" $NGINX_AVAILABLE

# Create symlink
ln -sf $NGINX_AVAILABLE $NGINX_ENABLED

# Test and reload Nginx
nginx -t
if [ $? -eq 0 ]; then
    systemctl reload nginx
    echo "Nginx configuration created for $DOMAIN"
else
    echo "Nginx configuration test failed!"
    rm -f $NGINX_ENABLED
    exit 1
fi
