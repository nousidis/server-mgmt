#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# PHP versions to install
PHP_VERSIONS=("7.4" "8.0" "8.1" "8.2" "8.3")

echo -e "${GREEN}Installing PHP versions...${NC}"

# Add PHP repository
add-apt-repository -y ppa:ondrej/php
apt-get update

# Install each PHP version with common extensions
for VERSION in "${PHP_VERSIONS[@]}"; do
    echo -e "${YELLOW}Installing PHP $VERSION...${NC}"

    apt-get install -y \
        php$VERSION-fpm \
        php$VERSION-cli \
        php$VERSION-common \
        php$VERSION-mysql \
        php$VERSION-pgsql \
        php$VERSION-sqlite3 \
        php$VERSION-curl \
        php$VERSION-gd \
        php$VERSION-mbstring \
        php$VERSION-xml \
        php$VERSION-zip \
        php$VERSION-bcmath \
        php$VERSION-intl \
        php$VERSION-readline \
        php$VERSION-msgpack \
        php$VERSION-igbinary \
        php$VERSION-redis \
        php$VERSION-memcached \
        php$VERSION-imagick

    # Start and enable PHP-FPM
    systemctl enable php$VERSION-fpm
    systemctl start php$VERSION-fpm
done

# Install Composer
echo -e "${YELLOW}Installing Composer...${NC}"
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
chmod +x /usr/local/bin/composer

echo -e "${GREEN}PHP installation completed!${NC}"
