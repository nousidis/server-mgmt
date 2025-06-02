#!/bin/bash

# VPS Manager Security Installation Script
# This script sets up security configurations and management user

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

echo -e "${BLUE}=== VPS Manager Security Installation ===${NC}"

# Copy all scripts to proper location
echo -e "${GREEN}Copying scripts to /usr/local/bin...${NC}"
cp -r ../* /usr/local/bin/
chmod -R +x /usr/local/bin/

# Get configuration
read -p "Enter admin username [vpsadmin]: " ADMIN_USER
ADMIN_USER=${ADMIN_USER:-vpsadmin}

read -p "Enter timezone [UTC]: " TIMEZONE
TIMEZONE=${TIMEZONE:-UTC}

# ===========================================
# INITIAL SECURITY SETUP
# ===========================================
echo -e "${GREEN}Running initial security setup...${NC}"

# Update system packages
echo -e "${YELLOW}Updating system packages...${NC}"
apt-get update && apt-get upgrade -y

# Set timezone
echo -e "${YELLOW}Setting timezone to $TIMEZONE...${NC}"
timedatectl set-timezone $TIMEZONE

# Configure firewall
echo -e "${YELLOW}Configuring UFW firewall...${NC}"
ufw --force enable
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw reload

# Create management user
ADMIN_PASSWORD=$(openssl rand -base64 32)
echo -e "${YELLOW}Creating management user: $ADMIN_USER...${NC}"

if ! id "$ADMIN_USER" &>/dev/null; then
    adduser --gecos "" --disabled-password $ADMIN_USER
    echo "$ADMIN_USER:$ADMIN_PASSWORD" | chpasswd
    usermod -aG sudo $ADMIN_USER
    
    # Copy SSH keys if they exist
    if [ -d /root/.ssh ] && [ -f /root/.ssh/authorized_keys ]; then
        mkdir -p /home/$ADMIN_USER/.ssh
        cp /root/.ssh/authorized_keys /home/$ADMIN_USER/.ssh/
        chown -R $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/.ssh
        chmod 700 /home/$ADMIN_USER/.ssh
        chmod 600 /home/$ADMIN_USER/.ssh/authorized_keys
    fi
fi

# Setup SSH security
echo -e "${YELLOW}Configuring SSH security...${NC}"
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd

# ===========================================
# INSTALL CONFIGURATION
# ===========================================
echo -e "${GREEN}Setting up VPS Manager configuration...${NC}"

# Create directories
mkdir -p /etc/vps-manager/configs
mkdir -p /var/log/vps-manager

# Set ownership and permissions
chown -R root:root /usr/local/bin
chmod -R 755 /usr/local/bin
chmod -R 700 /etc/vps-manager

# Configure sudo permissions
echo -e "${YELLOW}Configuring sudo permissions...${NC}"
cat > /etc/sudoers.d/vps-manager << EOF
# VPS Manager sudo configuration
$ADMIN_USER ALL=(ALL) NOPASSWD: /usr/local/bin/vps-manager
$ADMIN_USER ALL=(ALL) NOPASSWD: /usr/local/bin/setup/*
$ADMIN_USER ALL=(ALL) NOPASSWD: /usr/local/bin/php/*
$ADMIN_USER ALL=(ALL) NOPASSWD: /usr/local/bin/node/*
$ADMIN_USER ALL=(ALL) NOPASSWD: /usr/local/bin/database/*
$ADMIN_USER ALL=(ALL) NOPASSWD: /usr/local/bin/nginx/*
$ADMIN_USER ALL=(ALL) NOPASSWD: /usr/local/bin/sites/*
$ADMIN_USER ALL=(ALL) NOPASSWD: /usr/local/bin/utils/*
$ADMIN_USER ALL=(ALL) NOPASSWD: /bin/systemctl restart nginx
$ADMIN_USER ALL=(ALL) NOPASSWD: /bin/systemctl reload nginx
$ADMIN_USER ALL=(ALL) NOPASSWD: /bin/systemctl restart php*-fpm
$ADMIN_USER ALL=(ALL) NOPASSWD: /bin/systemctl reload php*-fpm
$ADMIN_USER ALL=(ALL) NOPASSWD: /usr/bin/supervisorctl *
$ADMIN_USER ALL=(ALL) NOPASSWD: /usr/bin/certbot *
$ADMIN_USER ALL=(ALL) NOPASSWD: /usr/bin/mysql
$ADMIN_USER ALL=(ALL) NOPASSWD: /usr/bin/mysqldump
$ADMIN_USER ALL=(ALL) NOPASSWD: /usr/bin/psql
$ADMIN_USER ALL=(ALL) NOPASSWD: /usr/bin/pg_dump
$ADMIN_USER ALL=(ALL) NOPASSWD: /usr/sbin/nginx
$ADMIN_USER ALL=(ALL) NOPASSWD: /usr/bin/pm2 *
EOF

chmod 440 /etc/sudoers.d/vps-manager

# ===========================================
# CREATE VPS-MANAGER-WRAPPER
# ===========================================
echo -e "${GREEN}Creating VPS Manager wrapper...${NC}"

cat > /usr/local/bin/vps-manager-wrapper << 'WRAPPER'
#!/bin/bash
# This wrapper ensures certain commands run with proper privileges

COMMAND=$1
shift

case "$COMMAND" in
    create-site|remove-site|backup-site|deploy|ssl-setup|update-perms)
        sudo /usr/local/bin/vps-manager "$COMMAND" "$@"
        ;;
    list-sites|site-info)
        # These don't need sudo
        /usr/local/bin/vps-manager "$COMMAND" "$@"
        ;;
    *)
        /usr/local/bin/vps-manager "$@"
        ;;
esac
WRAPPER

chmod +x /usr/local/bin/vps-manager-wrapper

# ===========================================
# CREATE ENHANCED VPS-MANAGER
# ===========================================
echo -e "${GREEN}Creating enhanced VPS Manager...${NC}"

cat > /usr/local/bin/vps-manager << 'VPSMANAGER'
#!/bin/bash

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
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] USER: ${SUDO_USER:-$USER} - ACTION: $*" >> $LOG_FILE
}

# Security check function
check_permissions() {
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
    validate_domain "$DOMAIN"
    
    echo "Framework options: laravel, php, nextjs, sveltekit, static"
    read -p "Framework: " FRAMEWORK
    validate_framework "$FRAMEWORK"
    
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
    
    $SCRIPT_DIR/sites/create-site.sh "$DOMAIN" "$FRAMEWORK" "$PHP_VERSION" "$DB_TYPE" "$GIT_REPO"
}

remove_site() {
    if [ -z "$2" ]; then
        read -p "Domain to remove: " DOMAIN
    else
        DOMAIN=$2
    fi
    
    validate_domain "$DOMAIN"
    
    read -p "Remove database? (yes/no) [no]: " REMOVE_DB
    REMOVE_DB=${REMOVE_DB:-"no"}
    
    read -p "Are you sure you want to remove $DOMAIN? (yes/no): " CONFIRM
    if [ "$CONFIRM" == "yes" ]; then
        $SCRIPT_DIR/sites/remove-site.sh "$DOMAIN" "$REMOVE_DB"
    else
        echo "Cancelled."
    fi
}

list_sites() {
    echo -e "${BLUE}Configured Sites:${NC}"
    echo ""
    
    for config in $CONFIG_DIR/configs/*.json; do
        if [ -f "$config" ]; then
            DOMAIN=$(jq -r '.domain' "$config")
            FRAMEWORK=$(jq -r '.framework' "$config")
            USER=$(jq -r '.user' "$config")
            CREATED=$(jq -r '.created' "$config")
            
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
    
    validate_domain "$DOMAIN"
    $SCRIPT_DIR/utils/backup-site.sh "$DOMAIN"
}

deploy_site() {
    if [ -z "$2" ]; then
        read -p "Domain to deploy: " DOMAIN
    else
        DOMAIN=$2
    fi
    
    validate_domain "$DOMAIN"
    
    if [ -z "$3" ]; then
        read -p "Git repository: " GIT_REPO
    else
        GIT_REPO=$3
    fi
    
    # Get framework from config
    FRAMEWORK=$(jq -r '.framework' "$CONFIG_DIR/configs/$DOMAIN.json")
    
    case $FRAMEWORK in
        laravel)
            $SCRIPT_DIR/sites/deploy-laravel.sh "$DOMAIN" "$GIT_REPO"
            ;;
        nextjs)
            $SCRIPT_DIR/sites/deploy-nextjs.sh "$DOMAIN" "$GIT_REPO"
            ;;
        sveltekit)
            $SCRIPT_DIR/sites/deploy-sveltekit.sh "$DOMAIN" "$GIT_REPO"
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
    
    validate_domain "$DOMAIN"
    
    CONFIG_FILE="$CONFIG_DIR/configs/$DOMAIN.json"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}Site not found: $DOMAIN${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Site Information: $DOMAIN${NC}"
    cat "$CONFIG_FILE" | jq '.'
    
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
    PHP_VERSION=$(jq -r '.php_version' "$CONFIG_FILE")
    if [ "$PHP_VERSION" != "null" ] && [ -f "/etc/php/$PHP_VERSION/fpm/pool.d/$DOMAIN.conf" ]; then
        echo -e "PHP-FPM: ${GREEN}Running (PHP $PHP_VERSION)${NC}"
    fi
    
    # PM2
    if pm2 list 2>/dev/null | grep -q "$DOMAIN"; then
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
    
    validate_domain "$DOMAIN"
    
    if [ -z "$3" ]; then
        read -p "Email for SSL notifications: " EMAIL
    else
        EMAIL=$3
    fi
    
    $SCRIPT_DIR/nginx/ssl-setup.sh "$DOMAIN" "$EMAIL"
}

update_perms() {
    if [ -z "$2" ]; then
        read -p "Domain: " DOMAIN
    else
        DOMAIN=$2
    fi
    
    validate_domain "$DOMAIN"
    $SCRIPT_DIR/utils/update-permissions.sh "$DOMAIN"
}

# Main logic
COMMAND=$1
check_permissions "$COMMAND"
log_action "Executing: $*"

case "$COMMAND" in
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
VPSMANAGER

chmod +x /usr/local/bin/vps-manager

# ===========================================
# CREATE SECURITY AUDIT SCRIPT
# ===========================================
echo -e "${GREEN}Creating security audit script...${NC}"

cat > /usr/local/bin/utils/security-audit.sh << 'SECAUDIT'
#!/bin/bash
# security-audit.sh - Run periodic security checks

echo "=== VPS Security Audit ==="
echo "Date: $(date)"
echo ""

# Check for users with sudo access
echo "Users with sudo access:"
grep -Po '^sudo.+:\K.*$' /etc/group
echo ""

# Check SSH configuration
echo "SSH Security Settings:"
grep -E "^(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication)" /etc/ssh/sshd_config
echo ""

# Check for sites running as root
echo "Checking for sites running as root (should be none):"
ps aux | grep -E "(php-fpm|node|npm)" | grep "root" | grep -v grep
echo ""

# Check file permissions
echo "Checking critical file permissions:"
ls -la /etc/vps-manager/
ls -la /etc/sudoers.d/
echo ""

# Check for failed login attempts
echo "Recent failed login attempts:"
grep "Failed password" /var/log/auth.log 2>/dev/null | tail -10
echo ""

# Check firewall status
echo "Firewall status:"
ufw status
echo ""

# Check for updates
echo "Security updates available:"
apt list --upgradable 2>/dev/null | grep -i security
SECAUDIT

chmod +x /usr/local/bin/utils/security-audit.sh

# ===========================================
# CREATE ROOT SETUP SCRIPT
# ===========================================
echo -e "${GREEN}Creating root setup script...${NC}"

cat > /usr/local/bin/root-setup.sh << 'ROOTSETUP'
#!/bin/bash

# This script runs the initial setup as root
# It's called automatically by the installer

echo "Running root setup tasks..."

# Ensure all scripts are executable
find /usr/local/bin -type f -name "*.sh" -exec chmod +x {} \;

# Create symlinks
ln -sf /usr/local/bin/vps-manager /usr/bin/vps-manager
ln -sf /usr/local/bin/vps-manager-wrapper /usr/bin/vps-manager-user

# Add alias for regular users
echo 'alias vps-manager="/usr/local/bin/vps-manager-wrapper"' >> /etc/bash.bashrc

# Initialize log file
touch /var/log/vps-manager/vps-manager.log
chmod 666 /var/log/vps-manager/vps-manager.log

echo "Root setup completed"
ROOTSETUP

chmod +x /usr/local/bin/root-setup.sh

# ===========================================
# FINAL SETUP
# ===========================================
echo -e "${GREEN}Running final setup...${NC}"

# Run root setup
/usr/local/bin/root-setup.sh

# Create initial log entry
echo "[$(date '+%Y-%m-%d %H:%M:%S')] VPS Manager security installed by root" > /var/log/vps-manager/vps-manager.log

# Save installation info
cat > /etc/vps-manager/installation-info.json << EOF
{
    "installed_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "admin_user": "$ADMIN_USER",
    "timezone": "$TIMEZONE",
    "security_configured": true
}
EOF

# Configure fail2ban if installed
if command -v fail2ban-client &> /dev/null; then
    echo -e "${YELLOW}Configuring fail2ban...${NC}"
    cat > /etc/fail2ban/jail.local << 'F2B'
[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
port = http,https
logpath = /var/log/nginx/*error.log
maxretry = 10
bantime = 3600
F2B
    systemctl restart fail2ban
fi

# ===========================================
# COMPLETION
# ===========================================
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Security Installation Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${YELLOW}Admin User:${NC} $ADMIN_USER"
echo -e "${YELLOW}Admin Password:${NC} $ADMIN_PASSWORD"
echo ""
echo -e "${RED}IMPORTANT: Save these credentials and change the password immediately!${NC}"
echo ""
echo "Security configurations applied:"
echo "✓ Root SSH login disabled"
echo "✓ Password authentication disabled (SSH keys only)"
echo "✓ UFW firewall enabled (ports 22, 80, 443)"
echo "✓ Admin user created with sudo access"
echo "✓ VPS Manager scripts configured"
echo ""
echo "Next steps:"
echo "1. Log out and log back in as $ADMIN_USER"
echo "2. Change your password: passwd"
echo "3. Run system setup: sudo /usr/local/bin/setup/00-initial-setup.sh"
echo "4. Install dependencies: sudo /usr/local/bin/setup/01-install-dependencies.sh"
echo "5. Create directory structure: sudo /usr/local/bin/setup/02-directory-structure.sh"
echo ""
echo "Then install your stack components as needed:"
echo "- PHP: sudo /usr/local/bin/php/install-php-versions.sh"
echo "- Node: sudo /usr/local/bin/node/install-pnpm.sh"
echo "- Nginx: sudo /usr/local/bin/nginx/install-nginx.sh"
echo "- MySQL: sudo /usr/local/bin/database/install-mysql.sh <password>"
echo ""
echo "Run 'vps-manager' for site management after setup"
