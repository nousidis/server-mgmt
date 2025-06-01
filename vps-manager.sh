#!/bin/bash
# Enhanced vps-manager.sh with security checks

SCRIPT_DIR="/usr/local/bin"
CONFIG_DIR="/etc/vps-manager"
LOG_FILE="/var/log/vps-manager/vps-manager.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log_action() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] USER: $USER - ACTION: $*" >> $LOG_FILE
}

# Security check function
check_permissions() {
    # Commands that require root/sudo
    PRIVILEGED_COMMANDS="create-site remove-site deploy ssl-setup update-perms"
    
    if [[ " $PRIVILEGED_COMMANDS " =~ " $1 " ]]; then
        if [ "$EUID" -ne 0 ]; then
            echo -e "${RED}Error: This command requires root privileges${NC}"
            echo "Please run with sudo or as root"
            exit 1
        fi
    fi
}

# Input validation
validate_domain() {
    local domain=$1
    if [[ ! "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]?\.[a-zA-Z]{2,}$ ]]; then
        echo -e "${RED}Error: Invalid domain name format${NC}"
        exit 1
    fi
}

validate_framework() {
    local framework=$1
    local valid_frameworks="laravel php nextjs sveltekit static"
    if [[ ! " $valid_frameworks " =~ " $framework " ]]; then
        echo -e "${RED}Error: Invalid framework. Choose from: $valid_frameworks${NC}"
        exit 1
    fi
}

# ... (include all the previous vps-manager functions with added validation)

# Main logic with security checks
COMMAND=$1
check_permissions $COMMAND
log_action "Executing: $*"

case "$COMMAND" in
    create-site)
        create_site
        ;;
    remove-site)
        remove_site $@
        ;;
    # ... rest of the cases
    *)
        show_help
        ;;
esac
