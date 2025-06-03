#!/bin/bash

SCRIPT_DIR="/usr/local/bin"
CONFIG_DIR="/etc/vps-manager"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
show_help() {
    echo -e "${BLUE}VPS Manager - Multi-Site Management System${NC}"
    echo ""
    echo "Usage: vps-manager <command> [options]"
    echo ""
    echo "Commands:"
    echo "  create-site    Create a new website"
    echo "  remove-site    Remove an existing website"
    echo "  list-sites     List all configured sites"
    echo "  backup-site    Backup a website"
    echo "  deploy         Deploy application to site"
    echo "  site-info      Show detailed site information"
    echo "  ssl-setup      Setup SSL certificate for a site"
    echo "  update-perms   Update site permissions"
    echo ""
    echo "Examples:"
    echo "  vps-manager create-site example.com laravel 8.2 mysql"
    echo "  vps-manager deploy example.com https://github.com/user/repo.git"
    echo "  vps-manager backup-site example.com"
}

create_site() {
    echo -e "${GREEN}Creating new site...${NC}"
    
    read -p "Domain name: " DOMAIN
    echo "Framework options: laravel, php, nextjs, sveltekit, static"
    read -p "Framework: " FRAMEWORK
    
    if [[ "$FRAMEWORK" == "laravel" || "$FRAMEWORK" == "php" ]]; then
        read -p "PHP version (7.4/8.0/8.1/8.2/8.3) [8.2]: " PHP_VERSION
        PHP_VERSION=${PHP_VERSION:-"8.2"}
    else
        PHP_VERSION=""
    fi
    
    echo "Database options: mysql, postgres, none"
    read -p "Database type [none]: " DB_TYPE
    DB_TYPE=${DB_TYPE:-"none"}
    
    read -p "Git repository (optional): " GIT_REPO
    
    $SCRIPT_DIR/sites/create-site.sh $DOMAIN $FRAMEWORK $PHP_VERSION $DB_TYPE $GIT_REPO
}

remove_site() {
    if [ -z "$2" ]; then
        read -p "Domain to remove: " DOMAIN
    else
        DOMAIN=$2
    fi
    
    read -p "Remove database? (yes/no) [no]: " REMOVE_DB
    REMOVE_DB=${REMOVE_DB:-"no"}
    
    read -p "Are you sure you want to remove $DOMAIN? (yes/no): " CONFIRM
    if [ "$CONFIRM" == "yes" ]; then
        $SCRIPT_DIR/sites/remove-site.sh $DOMAIN $REMOVE_DB
    else
        echo "Cancelled."
    fi
}

list_sites() {
    echo -e "${BLUE}Configured Sites:${NC}"
    echo ""
    
    for config in $CONFIG_DIR/configs/*.json; do
        if [ -f "$config" ]; then
            DOMAIN=$(jq -r '.domain' $config)
            FRAMEWORK=$(jq -r '.framework' $config)
            USER=$(jq -r '.user' $config)
            CREATED=$(jq -r '.created' $config)
            
            echo -e "${GREEN}$DOMAIN${NC}"
            echo "  Framework: $FRAMEWORK"
            echo "  User: $USER"
            echo "  Created: $CREATED"
            echo ""
        fi
    done
}

backup_site() {
    if [ -z "$2" ]; then
        read -p "Domain to backup: " DOMAIN
    else
        DOMAIN=$2
    fi
    
    $SCRIPT_DIR/utils/backup-site.sh $DOMAIN
}

deploy_site() {
    if [ -z "$2" ]; then
        read -p "Domain to deploy: " DOMAIN
    else
        DOMAIN=$2
    fi
    
    if [ -z "$3" ]; then
        read -p "Git repository: " GIT_REPO
    else
        GIT_REPO=$3
    fi
    
    # Get framework from config
    FRAMEWORK=$(jq -r '.framework' $CONFIG_DIR/configs/$DOMAIN.json)
    
    case $FRAMEWORK in
        laravel)
            $SCRIPT_DIR/sites/deploy-laravel.sh $DOMAIN $GIT_REPO
            ;;
        nextjs)
            $SCRIPT_DIR/sites/deploy-nextjs.sh $DOMAIN $GIT_REPO
            ;;
        sveltekit)
            $SCRIPT_DIR/sites/deploy-sveltekit.sh $DOMAIN $GIT_REPO
            ;;
        *)
            echo "Deployment not supported for framework: $FRAMEWORK"
            ;;
    esac
}

site_info() {
    if [ -z "$2" ]; then
        read -p "Domain: " DOMAIN
    else
        DOMAIN=$2
    fi
    
    CONFIG_FILE="$CONFIG_DIR/configs/$DOMAIN.json"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}Site not found: $DOMAIN${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Site Information: $DOMAIN${NC}"
    cat $CONFIG_FILE | jq '.'
    
    # Check services
    echo ""
    echo -e "${YELLOW}Service Status:${NC}"
    
    # Nginx
    if [ -f "/etc/nginx/sites-enabled/$DOMAIN" ]; then
        echo -e "Nginx: ${GREEN}Configured${NC}"
    else
        echo -e "Nginx: ${RED}Not configured${NC}"
    fi
    
    # PHP-FPM
    PHP_VERSION=$(jq -r '.php_version' $CONFIG_FILE)
    if [ "$PHP_VERSION" != "null" ] && [ -f "/etc/php/$PHP_VERSION/fpm/pool.d/$DOMAIN.conf" ]; then
        echo -e "PHP-FPM: ${GREEN}Running (PHP $PHP_VERSION)${NC}"
    fi
    
    # PM2
    if pm2 list | grep -q $DOMAIN; then
        echo -e "PM2: ${GREEN}Running${NC}"
    fi
    
    # SSL
    if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
        echo -e "SSL: ${GREEN}Enabled${NC}"
    else
        echo -e "SSL: ${YELLOW}Not configured${NC}"
    fi
}

ssl_setup() {
    if [ -z "$2" ]; then
        read -p "Domain: " DOMAIN
    else
        DOMAIN=$2
    fi
    
    read -p "Email for SSL notifications: " EMAIL
    
    $SCRIPT_DIR/nginx/ssl-setup.sh $DOMAIN $EMAIL
}

update_perms() {
    if [ -z "$2" ]; then
        read -p "Domain: " DOMAIN
    else
        DOMAIN=$2
    fi
    
    $SCRIPT_DIR/utils/update-permissions.sh $DOMAIN
}

# Main logic
case "$1" in
    create-site)
        create_site
        ;;
    remove-site)
        remove_site $@
        ;;
    list-sites)
        list_sites
        ;;
    backup-site)
        backup_site $@
        ;;
    deploy)
        deploy_site $@
        ;;
    site-info)
        site_info $@
        ;;
    ssl-setup)
        ssl_setup $@
        ;;
    update-perms)
        update_perms $@
        ;;
    *)
        show_help
        ;;
esac
