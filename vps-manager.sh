#!/bin/bash

SCRIPT_DIR="/usr/local/bin"
CONFIG_DIR="/etc/vps-manager"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Error handling
set -euo pipefail
trap 'echo -e "${RED}Error occurred at line $LINENO${NC}"' ERR
# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> /var/log/vps-manager.log
}

# Validation functions
validate_domain() {
    local domain=$1

    # This regex supports:
    # - Multiple subdomain levels (test.appalachian.digital)
    # - Domain names with hyphens (my-site.com)
    # - Multi-level TLDs (.co.uk, .com.au)
    # - Single level domains (example.com)

    if [[ ! "$domain" =~ ^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
        echo -e "${RED}Invalid domain format: $domain${NC}"
        return 1
    fi
}

validate_framework() {
    local framework=$1
    local valid_frameworks=("laravel" "php" "nextjs" "sveltekit" "static")
    if [[ ! " ${valid_frameworks[@]} " =~ " ${framework} " ]]; then
        echo -e "${RED}Invalid framework: $framework${NC}"
        echo "Valid options: ${valid_frameworks[*]}"
        return 1
    fi
}

validate_php_version() {
    local version=$1
    local valid_versions=("7.4" "8.0" "8.1" "8.2" "8.3")
    if [[ ! " ${valid_versions[@]} " =~ " ${version} " ]]; then
        echo -e "${RED}Invalid PHP version: $version${NC}"
        echo "Valid options: ${valid_versions[*]}"
        return 1
    fi
}

# Enhanced create_site function
create_site() {
    echo -e "${GREEN}Creating new site...${NC}"
    
    # Domain input with validation
    while true; do
        read -p "Domain name: " DOMAIN
        if validate_domain "$DOMAIN"; then
            break
        fi
    done
    
    # Check if site already exists
    if [ -f "$CONFIG_DIR/configs/$DOMAIN.json" ]; then
        echo -e "${RED}Site already exists: $DOMAIN${NC}"
        return 1
    fi
    
    # Framework selection
    echo "Framework options: laravel, php, nextjs, sveltekit, static"
    while true; do
        read -p "Framework: " FRAMEWORK
        if validate_framework "$FRAMEWORK"; then
            break
        fi
    done
    
    # PHP version for PHP frameworks
    if [[ "$FRAMEWORK" == "laravel" || "$FRAMEWORK" == "php" ]]; then
        while true; do
            read -p "PHP version (7.4/8.0/8.1/8.2/8.3) [8.2]: " PHP_VERSION
            PHP_VERSION=${PHP_VERSION:-"8.2"}
            if validate_php_version "$PHP_VERSION"; then
                break
            fi
        done
    else
        PHP_VERSION=""
    fi
    
    # Database selection
    echo "Database options: mysql, postgres, none"
    read -p "Database type [none]: " DB_TYPE
    DB_TYPE=${DB_TYPE:-"none"}
    
    # Git repository
    read -p "Git repository (optional): " GIT_REPO
    
    # Log the action
    log "Creating site: $DOMAIN with framework: $FRAMEWORK"
    
    # Execute with error handling
    if $SCRIPT_DIR/sites/create-site.sh "$DOMAIN" "$FRAMEWORK" "$PHP_VERSION" "$DB_TYPE" "$GIT_REPO"; then
        echo -e "${GREEN}Site created successfully!${NC}"
        log "Site created successfully: $DOMAIN"
    else
        echo -e "${RED}Failed to create site${NC}"
        log "Failed to create site: $DOMAIN"
        return 1
    fi
}

# Enhanced site listing with better formatting
list_sites() {
    echo -e "${BLUE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│                    Configured Sites                         │${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    
    local count=0
    for config in $CONFIG_DIR/configs/*.json; do
        if [ -f "$config" ]; then
            ((count++))
            local DOMAIN=$(jq -r '.domain' "$config")
            local FRAMEWORK=$(jq -r '.framework' "$config")
            local USER=$(jq -r '.user' "$config")
            local PHP_VERSION=$(jq -r '.php_version // "N/A"' "$config")
            local DB_TYPE=$(jq -r '.db_type // "none"' "$config")
            local CREATED=$(jq -r '.created' "$config")
            
            echo -e "${GREEN}[$count] $DOMAIN${NC}"
            echo "    ├─ Framework: $FRAMEWORK"
            echo "    ├─ User: $USER"
            [[ "$PHP_VERSION" != "N/A" && "$PHP_VERSION" != "null" ]] && echo "    ├─ PHP: $PHP_VERSION"
            [[ "$DB_TYPE" != "none" && "$DB_TYPE" != "null" ]] && echo "    ├─ Database: $DB_TYPE"
            echo "    └─ Created: $CREATED"
            echo ""
        fi
    done
    
    if [ $count -eq 0 ]; then
        echo -e "${YELLOW}No sites configured${NC}"
    else
        echo -e "${BLUE}Total sites: $count${NC}"
    fi
}

# Main execution with improved error handling
main() {
    case "${1:-}" in
        create-site)
            create_site
            ;;
        remove-site)
            remove_site "$@"
            ;;
        list-sites)
            list_sites
            ;;
        backup-site)
            backup_site "$@"
            ;;
        deploy)
            deploy_site "$@"
            ;;
        site-info)
            site_info "$@"
            ;;
        ssl-setup)
            ssl_setup "$@"
            ;;
        update-perms)
            update_perms "$@"
            ;;
        *)
            show_help
            ;;
    esac
}

# Execute main function
main "$@"
