#!/bin/bash

# VPS Manager Core - Core functions and utilities
# This script provides common functions used across all VPS Manager modules

# Set strict mode
set -euo pipefail

# Constants
export VPS_MANAGER_VERSION="1.0.0"
export SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export CONFIG_DIR="$SCRIPT_DIR/config"
export LOG_FILE="$SCRIPT_DIR/logs/vps-manager.log"
export BACKUP_DIR="$SCRIPT_DIR/backups"

# Ensure required directories exist
mkdir -p "$CONFIG_DIR/configs"
mkdir -p "$BACKUP_DIR"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

# Colors for terminal output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[1;37m'
export NC='\033[0m' # No Color

# ===== LOGGING FUNCTIONS =====

# Log a message to the log file
log() {
    local level="INFO"
    local message="$1"

    # If first parameter is a valid log level, use it
    if [[ "$1" == "INFO" || "$1" == "WARN" || "$1" == "ERROR" || "$1" == "DEBUG" ]]; then
        level="$1"
        message="$2"
    fi

    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"

    # For error level, also print to stderr
    if [[ "$level" == "ERROR" ]]; then
        echo -e "${RED}ERROR: $message${NC}" >&2
    fi

    # For debug level, only log if debug mode is enabled
    if [[ "$level" == "DEBUG" && -z "${DEBUG:-}" ]]; then
        return 0
    fi
}

# Log an error message and exit
error_exit() {
    log "ERROR" "$1"
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit "${2:-1}"
}

# Log a warning message
warn() {
    log "WARN" "$1"
    echo -e "${YELLOW}WARNING: $1${NC}" >&2
}

# Log a success message
success() {
    log "INFO" "$1"
    echo -e "${GREEN}$1${NC}"
}

# ===== VALIDATION FUNCTIONS =====

# Validate a domain name
validate_domain() {
    local domain=$1

    # This regex supports:
    # - Multiple subdomain levels (test.appalachian.digital)
    # - Domain names with hyphens (my-site.com)
    # - Multi-level TLDs (.co.uk, .com.au)
    # - Single level domains (example.com)

    if [[ ! "$domain" =~ ^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
        return 1
    fi

    return 0
}

# Validate a framework
validate_framework() {
    local framework=$1
    local valid_frameworks=("laravel" "php" "nextjs" "sveltekit" "static")

    # Use a loop to check each framework individually
    local is_valid=0
    for valid_framework in "${valid_frameworks[@]}"; do
        if [[ "$framework" == "$valid_framework" ]]; then
            is_valid=1
            break
        fi
    done

    if [[ $is_valid -eq 0 ]]; then
        return 1
    fi

    return 0
}

# Validate a PHP version
validate_php_version() {
    local version=$1
    local valid_versions=("7.4" "8.0" "8.1" "8.2" "8.3")

    # Use a loop to check each version individually
    local is_valid=0
    for valid_version in "${valid_versions[@]}"; do
        if [[ "$version" == "$valid_version" ]]; then
            is_valid=1
            break
        fi
    done

    if [[ $is_valid -eq 0 ]]; then
        return 1
    fi

    return 0
}

# Validate a database type
validate_db_type() {
    local db_type=$1
    local valid_types=("mysql" "postgres" "none")

    # Use a loop to check each database type individually
    local is_valid=0
    for valid_type in "${valid_types[@]}"; do
        if [[ "$db_type" == "$valid_type" ]]; then
            is_valid=1
            break
        fi
    done

    if [[ $is_valid -eq 0 ]]; then
        return 1
    fi

    return 0
}

# Validate a URL
validate_url() {
    local url=$1

    # Simplified regex pattern that checks if URL starts with http://, https://, or git://
    if [[ ! "$url" =~ ^(https?|git):// ]]; then
        return 1
    fi

    return 0
}

# Validate an email address
validate_email() {
    local email=$1

    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 1
    fi

    return 0
}

# ===== CONFIGURATION FUNCTIONS =====

# Load site configuration
load_site_config() {
    local domain=$1
    local config_file="$CONFIG_DIR/configs/$domain.json"

    if [ ! -f "$config_file" ]; then
        error_exit "Site configuration not found for $domain"
    fi

    # Export all configuration variables
    export SITE_DOMAIN="$domain"
    export SITE_USER=$(jq -r '.user' "$config_file")
    export SITE_FRAMEWORK=$(jq -r '.framework' "$config_file")
    export SITE_PHP_VERSION=$(jq -r '.php_version // "null"' "$config_file")
    export SITE_DB_TYPE=$(jq -r '.db_type // "none"' "$config_file")
    export SITE_PORT=$(jq -r '.port // "null"' "$config_file")
    export SITE_CREATED=$(jq -r '.created' "$config_file")
    export SITE_UPDATED=$(jq -r '.updated' "$config_file")

    # Load database credentials if they exist
    if [ -f "/home/$SITE_USER/.db_credentials" ]; then
        source "/home/$SITE_USER/.db_credentials"
        export DB_TYPE DB_NAME DB_USER DB_PASSWORD DB_HOST DB_PORT
    fi

    return 0
}

# Save site configuration
save_site_config() {
    local domain=$1
    local config_file="$CONFIG_DIR/configs/$domain.json"

    # Create config directory if it doesn't exist
    mkdir -p "$CONFIG_DIR/configs"

    # Create or update the configuration file
    cat > "$config_file" << EOF
{
    "domain": "$domain",
    "framework": "${SITE_FRAMEWORK:-}",
    "php_version": "${SITE_PHP_VERSION:-null}",
    "db_type": "${SITE_DB_TYPE:-none}",
    "user": "${SITE_USER:-}",
    "port": "${SITE_PORT:-null}",
    "created": "${SITE_CREATED:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}",
    "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

    log "INFO" "Configuration saved for $domain"
    return 0
}

# ===== UTILITY FUNCTIONS =====

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if a site exists
site_exists() {
    local domain=$1
    [ -f "$CONFIG_DIR/configs/$domain.json" ]
}

# Check if a user exists
user_exists() {
    local user=$1
    id "$user" >/dev/null 2>&1
}

# Generate a secure password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Create a directory with proper permissions
create_directory() {
    local dir=$1
    local owner=$2

    mkdir -p "$dir"
    chown -R "$owner:$owner" "$dir"
    chmod 755 "$dir"

    log "INFO" "Created directory $dir owned by $owner"
}

# Backup a site
backup_site() {
    local domain=$1
    local backup_dir="${2:-$BACKUP_DIR}"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$backup_dir/${domain}_${timestamp}.tar.gz"

    # Ensure backup directory exists
    mkdir -p "$backup_dir"

    # Create backup
    if tar -czf "$backup_file" -C /var/www "$domain" 2>/dev/null; then
        log "INFO" "Site $domain backed up to $backup_file"
        echo "$backup_file"
        return 0
    else
        log "ERROR" "Failed to backup site $domain"
        return 1
    fi
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error_exit "This script must be run as root" 1
    fi
}

# Execute a command as a specific user
run_as_user() {
    local user=$1
    shift
    sudo -u "$user" bash -c "$*"
}

# ===== HELP FUNCTIONS =====

# Show main help
show_main_help() {
    echo -e "${BLUE}VPS Manager v${VPS_MANAGER_VERSION} - Multi-Site Management System${NC}"
    echo ""
    echo "Usage: vps-manager <command> [options]"
    echo ""
    echo "Main Commands:"
    echo "  site        Manage websites (create, remove, list, info)"
    echo "  deploy      Deploy applications to sites"
    echo "  ssl         Manage SSL certificates"
    echo "  db          Manage databases"
    echo "  system      System management commands"
    echo "  logs        View and manage logs"
    echo ""
    echo "Run 'vps-manager <command> --help' for command-specific help"
    echo ""
    echo "Examples:"
    echo "  vps-manager site create example.com --framework=laravel --php=8.2 --database=mysql"
    echo "  vps-manager deploy example.com --repo=https://github.com/user/repo.git"
    echo "  vps-manager ssl enable example.com --email=admin@example.com"
    echo "  vps-manager db backup example.com"
    echo "  vps-manager system status"
    echo "  vps-manager logs tail example.com --lines=100"
}

# Show site command help
show_site_help() {
    echo -e "${BLUE}VPS Manager - Site Management${NC}"
    echo ""
    echo "Usage: vps-manager site <subcommand> [options]"
    echo ""
    echo "Subcommands:"
    echo "  create      Create a new website"
    echo "  remove      Remove an existing website"
    echo "  list        List all configured sites"
    echo "  info        Show detailed site information"
    echo "  backup      Backup a website"
    echo ""
    echo "Examples:"
    echo "  vps-manager site create example.com --framework=laravel --php=8.2 --database=mysql"
    echo "  vps-manager site remove example.com --backup"
    echo "  vps-manager site list"
    echo "  vps-manager site info example.com"
    echo "  vps-manager site backup example.com"
}

# Show deploy command help
show_deploy_help() {
    echo -e "${BLUE}VPS Manager - Deployment${NC}"
    echo ""
    echo "Usage: vps-manager deploy <domain> [options]"
    echo ""
    echo "Options:"
    echo "  --repo=URL      Git repository URL"
    echo "  --branch=NAME   Git branch to deploy (default: main)"
    echo "  --build         Run build process after deployment"
    echo ""
    echo "Examples:"
    echo "  vps-manager deploy example.com --repo=https://github.com/user/repo.git"
    echo "  vps-manager deploy example.com --branch=production --build"
}

# Show SSL command help
show_ssl_help() {
    echo -e "${BLUE}VPS Manager - SSL Management${NC}"
    echo ""
    echo "Usage: vps-manager ssl <subcommand> [options]"
    echo ""
    echo "Subcommands:"
    echo "  enable      Enable SSL for a site"
    echo "  disable     Disable SSL for a site"
    echo "  renew       Renew SSL certificates"
    echo "  status      Check SSL certificate status"
    echo ""
    echo "Examples:"
    echo "  vps-manager ssl enable example.com --email=admin@example.com"
    echo "  vps-manager ssl disable example.com"
    echo "  vps-manager ssl renew --all"
    echo "  vps-manager ssl status example.com"
}

# Show database command help
show_db_help() {
    echo -e "${BLUE}VPS Manager - Database Management${NC}"
    echo ""
    echo "Usage: vps-manager db <subcommand> [options]"
    echo ""
    echo "Subcommands:"
    echo "  create      Create a new database"
    echo "  backup      Backup a database"
    echo "  restore     Restore a database from backup"
    echo "  list        List all databases"
    echo ""
    echo "Examples:"
    echo "  vps-manager db create myapp_db --type=mysql --user=myapp_user"
    echo "  vps-manager db backup example.com"
    echo "  vps-manager db restore example.com --file=backup.sql"
    echo "  vps-manager db list"
}

# Show system command help
show_system_help() {
    echo -e "${BLUE}VPS Manager - System Management${NC}"
    echo ""
    echo "Usage: vps-manager system <subcommand> [options]"
    echo ""
    echo "Subcommands:"
    echo "  status      Show system status"
    echo "  update      Update system packages"
    echo "  upgrade     Upgrade VPS Manager"
    echo "  health      Run health checks"
    echo ""
    echo "Examples:"
    echo "  vps-manager system status"
    echo "  vps-manager system update"
    echo "  vps-manager system upgrade"
    echo "  vps-manager system health"
}

# Show logs command help
show_logs_help() {
    echo -e "${BLUE}VPS Manager - Logs Management${NC}"
    echo ""
    echo "Usage: vps-manager logs <subcommand> [options]"
    echo ""
    echo "Subcommands:"
    echo "  tail        Show the last lines of logs"
    echo "  view        View logs for a specific site"
    echo "  clear       Clear logs for a specific site"
    echo ""
    echo "Examples:"
    echo "  vps-manager logs tail example.com --lines=100"
    echo "  vps-manager logs view example.com --type=error"
    echo "  vps-manager logs clear example.com"
}

# ===== COMMAND PARSING FUNCTIONS =====

# Parse command line arguments
parse_args() {
    local args=("$@")
    local i=0
    local key
    local value

    # Initialize variables
    export ARGS=()
    export OPTS=()

    # Loop through arguments
    while [ $i -lt ${#args[@]} ]; do
        if [[ "${args[$i]}" == --* ]]; then
            # Handle --key=value format
            if [[ "${args[$i]}" == *=* ]]; then
                key="${args[$i]%%=*}"
                value="${args[$i]#*=}"
                export "${key:2}=${value}"
                OPTS+=("${key:2}" "${value}")
            # Handle --flag format (boolean)
            else
                key="${args[$i]}"
                export "${key:2}=true"
                OPTS+=("${key:2}" "true")
            fi
        else
            # Regular argument
            ARGS+=("${args[$i]}")
        fi
        ((i++))
    done

    return 0
}

# Get option value
get_opt() {
    local key=$1
    local default=${2:-}
    local i=0

    while [ $i -lt ${#OPTS[@]} ]; do
        if [ "${OPTS[$i]}" == "$key" ]; then
            echo "${OPTS[$i+1]}"
            return 0
        fi
        ((i+=2))
    done

    echo "$default"
    return 1
}

# Check if option exists
has_opt() {
    local key=$1
    local i=0

    while [ $i -lt ${#OPTS[@]} ]; do
        if [ "${OPTS[$i]}" == "$key" ]; then
            return 0
        fi
        ((i+=2))
    done

    return 1
}

# ===== INITIALIZATION =====

# Check if running as root, if not, re-run with sudo
if [ "$EUID" -ne 0 ]; then
    exec sudo "$0" "$@"
fi

# Export functions
export -f log error_exit warn success
export -f validate_domain validate_framework validate_php_version validate_db_type validate_url validate_email
export -f load_site_config save_site_config
export -f command_exists site_exists user_exists generate_password create_directory backup_site check_root run_as_user
export -f show_main_help show_site_help show_deploy_help show_ssl_help show_db_help show_system_help show_logs_help
export -f parse_args get_opt has_opt

# Log startup
log "INFO" "VPS Manager Core v${VPS_MANAGER_VERSION} initialized"
