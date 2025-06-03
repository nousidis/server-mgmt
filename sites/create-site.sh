#!/bin/bash

set -euo pipefail

DOMAIN=$1
FRAMEWORK=$2
PHP_VERSION=$3
DB_TYPE=$4
GIT_REPO=$5

if [ -z "$DOMAIN" ] || [ -z "$FRAMEWORK" ]; then
    echo "Usage: $0 <domain> <framework> [php_version] [db_type] [git_repo]"
    echo "Frameworks: laravel, php, nextjs, sveltekit, static"
    echo "DB Types: mysql, postgres, none"
    exit 1
fi

# Set defaults
PHP_VERSION=${PHP_VERSION:-"8.2"}
DB_TYPE=${DB_TYPE:-"none"}

# Create safe username (replace dots and special chars)
USER=$(echo "${DOMAIN}" | sed 's/[^a-zA-Z0-9]/_/g' | cut -c1-32)

# Check if user already exists
if id "$USER" &>/dev/null; then
    echo "User $USER already exists"
    exit 1
fi

# Create user with proper home directory
useradd -m -s /bin/bash "$USER"

# Create directory structure with proper permissions
create_directory() {
    local dir=$1
    local owner=$2
    mkdir -p "$dir"
    chown -R "$owner:$owner" "$dir"
    chmod 755 "$dir"
}

create_directory "/var/www/$DOMAIN" "$USER"
create_directory "/var/log/sites/$DOMAIN" "$USER"
create_directory "/home/$USER/.ssh" "$USER"
chmod 700 "/home/$USER/.ssh"

# Create database if needed
if [ "$DB_TYPE" != "none" ]; then
    DB_NAME="${USER}_db"
    DB_USER="${USER}_user"
    DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    
    case "$DB_TYPE" in
        mysql)
            if /usr/local/bin/database/create-mysql-database.sh "$DB_NAME" "$DB_USER" "$DB_PASSWORD"; then
                echo "MySQL database created successfully"
            else
                echo "Failed to create MySQL database"
                exit 1
            fi
            ;;
        postgres)
            if /usr/local/bin/database/create-postgres-database.sh "$DB_NAME" "$DB_USER" "$DB_PASSWORD"; then
                echo "PostgreSQL database created successfully"
            else
                echo "Failed to create PostgreSQL database"
                exit 1
            fi
            ;;
    esac
    
    # Save credentials securely
    cat > "/home/$USER/.db_credentials" << EOF
DB_TYPE=$DB_TYPE
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
DB_HOST=localhost
DB_PORT=$([[ "$DB_TYPE" == "mysql" ]] && echo "3306" || echo "5432")
EOF
    chown "$USER:$USER" "/home/$USER/.db_credentials"
    chmod 600 "/home/$USER/.db_credentials"
fi

# Setup PHP if needed
if [[ "$FRAMEWORK" == "laravel" || "$FRAMEWORK" == "php" ]]; then
    /usr/local/bin/php/create-php-pool.sh "$DOMAIN" "$PHP_VERSION" "$USER"
fi

# Setup Node.js if needed
PORT=""
if [[ "$FRAMEWORK" == "nextjs" || "$FRAMEWORK" == "sveltekit" ]]; then
    # Find available port
    PORT=$(comm -23 <(seq 3000 4000 | sort) <(ss -tan | awk '{print $4}' | cut -d':' -f2 | grep -E '^[0-9]+$' | sort -u) | head -n1)
    echo "PORT=$PORT" > "/home/$USER/.port"
    chown "$USER:$USER" "/home/$USER/.port"
    
    # Setup Node version
    /usr/local/bin/node/setup-node-version.sh "$DOMAIN" "18" "$USER"
fi

# Create Nginx config
/usr/local/bin/nginx/create-site.sh "$DOMAIN" "$FRAMEWORK" "$PHP_VERSION" "$PORT"

# Clone repository if provided
if [ ! -z "$GIT_REPO" ]; then
    # Setup Git SSH for the user
    sudo -u "$USER" bash -c "
        cd /var/www/$DOMAIN
        git config --global init.defaultBranch main
        git clone '$GIT_REPO' .
    " || echo "Warning: Git clone failed"
fi

# Create environment file based on framework
case "$FRAMEWORK" in
    laravel)
        if [ -f "/usr/local/bin/config/templates/env.laravel" ]; then
            envsubst < "/usr/local/bin/config/templates/env.laravel" > "/var/www/$DOMAIN/.env"
            chown "$USER:$USER" "/var/www/$DOMAIN/.env"
            chmod 600 "/var/www/$DOMAIN/.env"
        fi
        ;;
    nextjs|sveltekit)
        if [ -f "/usr/local/bin/config/templates/env.nextjs" ]; then
            envsubst < "/usr/local/bin/config/templates/env.nextjs" > "/var/www/$DOMAIN/.env"
            chown "$USER:$USER" "/var/www/$DOMAIN/.env"
            chmod 600 "/var/www/$DOMAIN/.env"
        fi
        ;;
esac

# Save site configuration
mkdir -p "/etc/vps-manager/configs"
cat > "/etc/vps-manager/configs/$DOMAIN.json" << EOF
{
    "domain": "$DOMAIN",
    "framework": "$FRAMEWORK",
    "php_version": "$PHP_VERSION",
    "db_type": "$DB_TYPE",
    "user": "$USER",
    "port": "$PORT",
    "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo ""
echo "==================================="
echo "Site created successfully!"
echo "==================================="
echo "Domain: $DOMAIN"
echo "User: $USER"
echo "Directory: /var/www/$DOMAIN"
echo "Framework: $FRAMEWORK"
[[ "$PHP_VERSION" && "$PHP_VERSION" != "null" ]] && echo "PHP Version: $PHP_VERSION"
[[ "$PORT" ]] && echo "Port: $PORT"
[[ "$DB_TYPE" != "none" ]] && echo "Database: $DB_TYPE (credentials in /home/$USER/.db_credentials)"
echo "==================================="
