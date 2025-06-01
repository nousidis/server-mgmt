#!/bin/bash

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

# Create user
USER="${DOMAIN//./_}"
useradd -m -s /bin/bash $USER

# Create directory structure
mkdir -p /var/www/$DOMAIN
mkdir -p /var/log/sites/$DOMAIN
mkdir -p /home/$USER/.ssh

# Set permissions
chown -R $USER:$USER /var/www/$DOMAIN
chown -R $USER:$USER /var/log/sites/$DOMAIN
chown -R $USER:$USER /home/$USER/.ssh

# Create database if needed
if [ "$DB_TYPE" != "none" ]; then
    DB_NAME="${USER}_db"
    DB_USER="${USER}_user"
    DB_PASSWORD=$(openssl rand -base64 32)
    
    if [ "$DB_TYPE" == "mysql" ]; then
        /usr/local/bin/database/create-mysql-database.sh $DB_NAME $DB_USER $DB_PASSWORD
    elif [ "$DB_TYPE" == "postgres" ]; then
        /usr/local/bin/database/create-postgres-database.sh $DB_NAME $DB_USER $DB_PASSWORD
    fi
    
    # Save credentials
    cat > /home/$USER/.db_credentials << EOF
DB_TYPE=$DB_TYPE
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
EOF
    chown $USER:$USER /home/$USER/.db_credentials
    chmod 600 /home/$USER/.db_credentials
fi

# Setup PHP if needed
if [[ "$FRAMEWORK" == "laravel" || "$FRAMEWORK" == "php" ]]; then
    /usr/local/bin/php/create-php-pool.sh $DOMAIN $PHP_VERSION $USER
fi

# Setup Node.js if needed
if [[ "$FRAMEWORK" == "nextjs" || "$FRAMEWORK" == "sveltekit" ]]; then
    # Assign port
    PORT=$(shuf -i 3000-4000 -n 1)
    echo "PORT=$PORT" > /home/$USER/.port
    chown $USER:$USER /home/$USER/.port
    
    # Setup Node version
    /usr/local/bin/node/setup-node-version.sh $DOMAIN "18" $USER
else
    PORT=""
fi

# Create Nginx config
/usr/local/bin/nginx/create-site.sh $DOMAIN $FRAMEWORK $PHP_VERSION $PORT

# Clone repository if provided
if [ ! -z "$GIT_REPO" ]; then
    su - $USER -c "git clone $GIT_REPO /var/www/$DOMAIN"
fi

# Save site config
cat > /etc/vps-manager/configs/$DOMAIN.json << EOF
{
    "domain": "$DOMAIN",
    "framework": "$FRAMEWORK",
    "php_version": "$PHP_VERSION",
    "db_type": "$DB_TYPE",
    "user": "$USER",
    "port": "$PORT",
    "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo "Site created successfully!"
echo "Domain: $DOMAIN"
echo "User: $USER"
echo "Directory: /var/www/$DOMAIN"
if [ "$DB_TYPE" != "none" ]; then
    echo "Database credentials saved in: /home/$USER/.db_credentials"
fi
