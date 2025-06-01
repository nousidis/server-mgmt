#!/bin/bash

DOMAIN=$1
REMOVE_DB=$2

if [ -z "$DOMAIN" ]; then
    echo "Usage: $0 <domain> [remove_db:yes/no]"
    exit 1
fi

REMOVE_DB=${REMOVE_DB:-"no"}

# Get site info
if [ ! -f "/etc/vps-manager/configs/$DOMAIN.json" ]; then
    echo "Site configuration not found for $DOMAIN"
    exit 1
fi

USER=$(jq -r '.user' /etc/vps-manager/configs/$DOMAIN.json)
PHP_VERSION=$(jq -r '.php_version' /etc/vps-manager/configs/$DOMAIN.json)
DB_TYPE=$(jq -r '.db_type' /etc/vps-manager/configs/$DOMAIN.json)

# Stop services
pm2 delete $DOMAIN 2>/dev/null || true
supervisorctl stop $DOMAIN-worker:* 2>/dev/null || true

# Remove Nginx config
rm -f /etc/nginx/sites-enabled/$DOMAIN
rm -f /etc/nginx/sites-available/$DOMAIN
nginx -t && systemctl reload nginx

# Remove PHP-FPM pool
if [ "$PHP_VERSION" != "null" ]; then
    rm -f /etc/php/$PHP_VERSION/fpm/pool.d/$DOMAIN.conf
    systemctl reload php$PHP_VERSION-fpm
fi

# Archive site files
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
tar -czf /var/backups/sites/${DOMAIN}_${TIMESTAMP}.tar.gz -C /var/www $DOMAIN

# Remove site files
rm -rf /var/www/$DOMAIN

# Remove database if requested
if [ "$REMOVE_DB" == "yes" ] && [ "$DB_TYPE" != "none" ] && [ "$DB_TYPE" != "null" ]; then
    if [ -f "/home/$USER/.db_credentials" ]; then
        source /home/$USER/.db_credentials
        
        if [ "$DB_TYPE" == "mysql" ]; then
            mysql -u root -p << EOF
DROP DATABASE IF EXISTS $DB_NAME;
DROP USER IF EXISTS '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
        elif [ "$DB_TYPE" == "postgres" ]; then
            sudo -u postgres psql << EOF
DROP DATABASE IF EXISTS $DB_NAME;
DROP USER IF EXISTS $DB_USER;
EOF
        fi
    fi
fi

# Remove user
userdel -r $USER 2>/dev/null || true

# Remove supervisor config
rm -f /etc/supervisor/conf.d/$DOMAIN-worker.conf
supervisorctl reread
supervisorctl update

# Remove logs
rm -rf /var/log/sites/$DOMAIN

# Remove config
rm -f /etc/vps-manager/configs/$DOMAIN.json

echo "Site $DOMAIN removed. Backup saved to /var/backups/sites/${DOMAIN}_${TIMESTAMP}.tar.gz"
