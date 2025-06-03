#!/bin/bash

set -euo pipefail

DOMAIN=$1
GIT_REPO=$2

if [ -z "$DOMAIN" ]; then
    echo "Usage: $0 <domain> [git_repo]"
    exit 1
fi

# Get site info
CONFIG_FILE="/etc/vps-manager/configs/$DOMAIN.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Site configuration not found for $DOMAIN"
    exit 1
fi

USER=$(jq -r '.user' "$CONFIG_FILE")
PHP_VERSION=$(jq -r '.php_version' "$CONFIG_FILE")
FRAMEWORK=$(jq -r '.framework' "$CONFIG_FILE")

if [ "$FRAMEWORK" != "laravel" ]; then
    echo "This deployment script is for Laravel sites only"
    exit 1
fi

echo "Deploying Laravel application for $DOMAIN..."

# Create deployment script to run as user
DEPLOY_SCRIPT=$(mktemp)
cat > "$DEPLOY_SCRIPT" << 'DEPLOY_EOF'
#!/bin/bash
set -euo pipefail

cd /var/www/DOMAIN_PLACEHOLDER

# Pull latest code if git repo exists
if [ -d .git ]; then
    echo "Pulling latest changes..."
    git pull origin main || git pull origin master
elif [ ! -z "GIT_REPO_PLACEHOLDER" ]; then
    echo "Cloning repository..."
    git clone GIT_REPO_PLACEHOLDER .
fi

# Check if composer.json exists
if [ ! -f composer.json ]; then
    echo "No composer.json found. Is this a Laravel project?"
    exit 1
fi

# Install/update dependencies
echo "Installing composer dependencies..."
composer install --no-interaction --prefer-dist --optimize-autoloader --no-dev

# Laravel specific tasks
if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        cp .env.example .env
        php artisan key:generate
    else
        echo "Warning: No .env file found and no .env.example to copy"
    fi
fi

# Load database credentials if they exist
if [ -f ~/.db_credentials ]; then
    source ~/.db_credentials
    
    # Update .env with database credentials
    if [ -f .env ]; then
        sed -i "s/DB_CONNECTION=.*/DB_CONNECTION=$DB_TYPE/" .env
        sed -i "s/DB_HOST=.*/DB_HOST=$DB_HOST/" .env
        sed -i "s/DB_PORT=.*/DB_PORT=$DB_PORT/" .env
        sed -i "s/DB_DATABASE=.*/DB_DATABASE=$DB_NAME/" .env
        sed -i "s/DB_USERNAME=.*/DB_USERNAME=$DB_USER/" .env
        sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$DB_PASSWORD/" .env
    fi
fi

# Run migrations
echo "Running migrations..."
php artisan migrate --force || echo "Migration failed or no migrations to run"

# Clear and optimize
echo "Optimizing application..."
php artisan cache:clear
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan optimize

# Set permissions for Laravel
chmod -R 775 storage bootstrap/cache
find storage -type d -exec chmod 775 {} \;
find bootstrap/cache -type d -exec chmod 775 {} \;

echo "Deployment completed!"
DEPLOY_EOF

# Replace placeholders
sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" "$DEPLOY_SCRIPT"
sed -i "s|GIT_REPO_PLACEHOLDER|$GIT_REPO|g" "$DEPLOY_SCRIPT"

# Make script executable and run as user
chmod +x "$DEPLOY_SCRIPT"
sudo -u "$USER" bash "$DEPLOY_SCRIPT"
rm -f "$DEPLOY_SCRIPT"

# Setup queue worker if artisan queue:work exists
if sudo -u "$USER" php "/var/www/$DOMAIN/artisan" list | grep -q "queue:work"; then
    echo "Setting up queue worker..."
    SUPERVISOR_CONF="/etc/supervisor/conf.d/$DOMAIN-worker.conf"
    cat > "$SUPERVISOR_CONF" << EOF
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
    supervisorctl start "$DOMAIN-worker:*" || true
fi

# Update site config
jq '.updated = "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

echo "Laravel application deployed successfully for $DOMAIN"
