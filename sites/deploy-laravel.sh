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
PHP_VERSION=$(jq -r '.php_version' /etc/vps-manager/configs/$DOMAIN.json)

# Clone or pull repository
if [ ! -z "$GIT_REPO" ]; then
    if [ ! -d "/var/www/$DOMAIN/.git" ]; then
        su - $USER -c "git clone $GIT_REPO /var/www/$DOMAIN"
    else
        su - $USER -c "cd /var/www/$DOMAIN && git pull"
    fi
fi

# Laravel deployment
su - $USER -c "
    cd /var/www/$DOMAIN
    
    # Install dependencies
    composer install --no-interaction --prefer-dist --optimize-autoloader --no-dev
    
    # Setup environment
    if [ ! -f .env ]; then
        cp .env.example .env
        php artisan key:generate
    fi
    
    # Run migrations
    php artisan migrate --force
    
    # Clear and cache
    php artisan cache:clear
    php artisan config:cache
    php artisan route:cache
    php artisan view:cache
    
    # Set permissions
    chmod -R 775 storage bootstrap/cache
"

# Setup queue worker if needed
SUPERVISOR_CONF="/etc/supervisor/conf.d/$DOMAIN-worker.conf"
cat > $SUPERVISOR_CONF << EOF
[program:$DOMAIN-worker]
process_name=%(program_name)s_%(process_num)02d
command=/usr/bin/php /var/www/$DOMAIN/artisan queue:work --sleep=3 --tries=3 --max-time=3600
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
user=$USER
numprocs=2
redirect_stderr=true
stdout_logfile=/var/log/sites/$DOMAIN/worker.log
stopwaitsecs=3600
EOF

supervisorctl reread
supervisorctl update
supervisorctl start $DOMAIN-worker:*

echo "Laravel application deployed for $DOMAIN"
