#!/bin/bash

# Arguments
DOMAIN=$1
PHP_VERSION=$2
USER=$3

if [ -z "$DOMAIN" ] || [ -z "$PHP_VERSION" ] || [ -z "$USER" ]; then
    echo "Usage: $0 <domain> <php_version> <user>"
    exit 1
fi

POOL_FILE="/etc/php/$PHP_VERSION/fpm/pool.d/$DOMAIN.conf"

cat > $POOL_FILE << EOF
[$DOMAIN]
user = $USER
group = $USER
listen = /run/php/php$PHP_VERSION-fpm-$DOMAIN.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
pm.process_idle_timeout = 10s
pm.max_requests = 500

; Logging
access.log = /var/log/sites/$DOMAIN/php-access.log
slowlog = /var/log/sites/$DOMAIN/php-slow.log
request_slowlog_timeout = 5s

; Environment variables
env[HOSTNAME] = \$HOSTNAME
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] = /tmp

; PHP settings
php_admin_value[error_log] = /var/log/sites/$DOMAIN/php-error.log
php_admin_flag[log_errors] = on
php_admin_value[memory_limit] = 256M
php_admin_value[upload_max_filesize] = 50M
php_admin_value[post_max_size] = 50M
php_admin_value[max_execution_time] = 300
php_admin_value[open_basedir] = /var/www/$DOMAIN:/tmp:/usr/share/php
EOF

# Create log directory
mkdir -p /var/log/sites/$DOMAIN
chown -R $USER:$USER /var/log/sites/$DOMAIN

# Restart PHP-FPM
systemctl reload php$PHP_VERSION-fpm

echo "PHP-FPM pool created for $DOMAIN with PHP $PHP_VERSION"
