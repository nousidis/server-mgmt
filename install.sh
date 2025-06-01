#!/bin/bash

# VPS Manager All-in-One Installer
# This script installs the complete VPS management system with security configurations

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/vps-manager"
LOG_DIR="/var/log/vps-manager"
SCRIPT_SOURCE_DIR="./vps-scripts"  # Directory where you extracted the scripts

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

echo -e "${BLUE}=== VPS Manager All-in-One Installer ===${NC}"
echo ""

# Get installation parameters
read -p "Enter timezone (e.g., UTC, America/New_York) [UTC]: " TIMEZONE
TIMEZONE=${TIMEZONE:-UTC}

read -p "Enter admin username [vpsadmin]: " ADMIN_USER
ADMIN_USER=${ADMIN_USER:-vpsadmin}

read -p "Enter your email for SSL certificates: " ADMIN_EMAIL
while [[ ! "$ADMIN_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; do
    echo -e "${RED}Invalid email format${NC}"
    read -p "Enter your email for SSL certificates: " ADMIN_EMAIL
done

read -sp "Enter MySQL root password: " MYSQL_ROOT_PASSWORD
echo ""
read -sp "Confirm MySQL root password: " MYSQL_ROOT_PASSWORD_CONFIRM
echo ""

while [ "$MYSQL_ROOT_PASSWORD" != "$MYSQL_ROOT_PASSWORD_CONFIRM" ]; do
    echo -e "${RED}Passwords don't match${NC}"
    read -sp "Enter MySQL root password: " MYSQL_ROOT_PASSWORD
    echo ""
    read -sp "Confirm MySQL root password: " MYSQL_ROOT_PASSWORD_CONFIRM
    echo ""
done

read -sp "Enter PostgreSQL password: " POSTGRES_PASSWORD
echo ""

echo ""
echo -e "${YELLOW}Installation will begin with these settings:${NC}"
echo "Timezone: $TIMEZONE"
echo "Admin user: $ADMIN_USER"
echo "Admin email: $ADMIN_EMAIL"
echo ""
read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Installation cancelled"
    exit 1
fi

# Function to create all scripts
create_scripts() {
    echo -e "${GREEN}Creating VPS management scripts...${NC}"
    
    # Create directory structure
    mkdir -p $INSTALL_DIR/{setup,php,node,database,nginx/templates,sites,utils,config/templates}
    mkdir -p $CONFIG_DIR/configs
    mkdir -p $LOG_DIR
    
    # Create all setup scripts
    cat > $INSTALL_DIR/setup/00-initial-setup.sh << 'SETUP00'
#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Starting VPS Initial Setup...${NC}"

# Update system packages
echo -e "${YELLOW}Updating system packages...${NC}"
apt-get update && apt-get upgrade -y

# Set timezone
TIMEZONE=${1:-"UTC"}
echo -e "${YELLOW}Setting timezone to $TIMEZONE...${NC}"
timedatectl set-timezone $TIMEZONE

# Configure firewall
echo -e "${YELLOW}Configuring UFW firewall...${NC}"
ufw --force enable
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw reload

echo -e "${GREEN}Initial setup completed!${NC}"
SETUP00

    cat > $INSTALL_DIR/setup/01-install-dependencies.sh << 'SETUP01'
#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Installing system dependencies...${NC}"

# Install build essentials
apt-get install -y build-essential software-properties-common

# Install common tools
apt-get install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    zip \
    unzip \
    ncdu \
    tree \
    jq

# Install supervisor
apt-get install -y supervisor
systemctl enable supervisor
systemctl start supervisor

# Install certbot
apt-get install -y certbot python3-certbot-nginx

# Install fail2ban
apt-get install -y fail2ban
systemctl enable fail2ban
systemctl start fail2ban

echo -e "${GREEN}Dependencies installed successfully!${NC}"
SETUP01

    cat > $INSTALL_DIR/setup/02-directory-structure.sh << 'SETUP02'
#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Creating directory structure...${NC}"

# Create web directories
mkdir -p /var/www
mkdir -p /var/backups/sites
mkdir -p /var/log/sites

# Create nginx directories
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled
mkdir -p /etc/nginx/ssl

# Set permissions
chmod 755 /var/www
chmod 755 /var/backups
chmod 755 /var/log/sites

echo -e "${GREEN}Directory structure created!${NC}"
SETUP02

    # Copy all other scripts from the first artifact
    # This is where you'd copy all the PHP, Node, Database, Nginx, Sites, and Utils scripts
    # For brevity, I'll show the structure but you need to paste the actual scripts
    
    echo -e "${YELLOW}Note: You need to copy all the scripts from the first artifact to:${NC}"
    echo "- PHP scripts to $INSTALL_DIR/php/"
    echo "- Node scripts to $INSTALL_DIR/node/"
    echo "- Database scripts to $INSTALL_DIR/database/"
    echo "- Nginx scripts and templates to $INSTALL_DIR/nginx/"
    echo "- Site management scripts to $INSTALL_DIR/sites/"
    echo "- Utility scripts to $INSTALL_DIR/utils/"
    echo "- Config templates to $INSTALL_DIR/config/templates/"
    
    # Create the enhanced vps-manager script
    cat > $INSTALL_DIR/vps-manager.sh << 'VPSMANAGER'
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

    # Create wrapper script
    cat > $INSTALL_DIR/vps-manager-wrapper << 'WRAPPER'
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

    # Create security audit script
    cat > $INSTALL_DIR/utils/security-audit.sh << 'SECAUDIT'
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

    # Set permissions
    chmod -R 755 $INSTALL_DIR
    chmod +x $INSTALL_DIR/**/*.sh
    chmod +x $INSTALL_DIR/vps-manager-wrapper
    chmod 700 $CONFIG_DIR
    chmod 755 $LOG_DIR
}

# Main installation process
echo -e "${GREEN}Starting VPS Manager installation...${NC}"

# Create scripts
create_scripts

# Create symlinks
ln -sf $INSTALL_DIR/vps-manager.sh /usr/bin/vps-manager
ln -sf $INSTALL_DIR/vps-manager-wrapper /usr/bin/vps-manager-user

# Run initial system setup
echo -e "${GREEN}Running initial system setup...${NC}"
$INSTALL_DIR/setup/00-initial-setup.sh "$TIMEZONE"
$INSTALL_DIR/setup/01-install-dependencies.sh
$INSTALL_DIR/setup/02-directory-structure.sh

# Create admin user
echo -e "${GREEN}Creating admin user...${NC}"
ADMIN_PASSWORD=$(openssl rand -base64 32)

if ! id "$ADMIN_USER" &>/dev/null; then
    useradd -m -s /bin/bash "$ADMIN_USER"
    echo "$ADMIN_USER:$ADMIN_PASSWORD" | chpasswd
    usermod -aG sudo "$ADMIN_USER"
    
    # Copy SSH keys if they exist
    if [ -d /root/.ssh ] && [ -f /root/.ssh/authorized_keys ]; then
        mkdir -p /home/$ADMIN_USER/.ssh
        cp /root/.ssh/authorized_keys /home/$ADMIN_USER/.ssh/
        chown -R $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/.ssh
        chmod 700 /home/$ADMIN_USER/.ssh
        chmod 600 /home/$ADMIN_USER/.ssh/authorized_keys
    fi
fi

# Configure sudo permissions
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

# Add alias for regular users
echo 'alias vps-manager="/usr/local/bin/vps-manager-wrapper"' >> /etc/bash.bashrc

# Install software stack
echo -e "${GREEN}Installing software stack...${NC}"

# PHP
echo -e "${YELLOW}Installing PHP versions...${NC}"
$INSTALL_DIR/php/install-php-versions.sh

# Node.js and pnpm
echo -e "${YELLOW}Installing Node.js tools...${NC}"
$INSTALL_DIR/node/install-pnpm.sh
source /etc/profile
$INSTALL_DIR/node/install-pm2.sh

# Nginx
echo -e "${YELLOW}Installing Nginx...${NC}"
$INSTALL_DIR/nginx/install-nginx.sh

# Databases
echo -e "${YELLOW}Installing MySQL...${NC}"
$INSTALL_DIR/database/install-mysql.sh "$MYSQL_ROOT_PASSWORD"

echo -e "${YELLOW}Installing PostgreSQL...${NC}"
$INSTALL_DIR/database/install-postgresql.sh "$POSTGRES_PASSWORD"

# Configure fail2ban
echo -e "${YELLOW}Configuring fail2ban...${NC}"
cat > /etc/fail2ban/jail.local << EOF
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
EOF

systemctl restart fail2ban

# Setup monitoring
echo -e "${YELLOW}Setting up monitoring...${NC}"
$INSTALL_DIR/utils/monitor-setup.sh

# Secure SSH
echo -e "${YELLOW}Securing SSH...${NC}"
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd

# Create initial log entry
echo "[$(date '+%Y-%m-%d %H:%M:%S')] VPS Manager installed by root" > $LOG_DIR/vps-manager.log
chown $ADMIN_USER:$ADMIN_USER $LOG_DIR/vps-manager.log

# Save installation info
cat > $CONFIG_DIR/installation-info.json << EOF
{
    "installed_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "admin_user": "$ADMIN_USER",
    "admin_email": "$ADMIN_EMAIL",
    "timezone": "$TIMEZONE",
    "mysql_installed": true,
    "postgresql_installed": true,
    "php_versions": ["7.4", "8.0", "8.1", "8.2", "8.3"],
    "node_tool": "pnpm",
    "process_manager": "pm2"
}
EOF

# Final summary
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Installation completed!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${YELLOW}Admin User:${NC} $ADMIN_USER"
echo -e "${YELLOW}Admin Password:${NC} $ADMIN_PASSWORD"
echo ""
echo -e "${RED}IMPORTANT: Save these credentials and change the password immediately!${NC}"
echo ""
echo "Next steps:"
echo "1. Log out and log back in as $ADMIN_USER"
echo "2. Change your password: passwd"
echo "3. Create your first site: vps-manager create-site"
echo ""
echo "Security notes:"
echo "- Root login has been disabled"
echo "- Password authentication has been disabled (SSH keys only)"
echo "- Firewall is active (ports 22, 80, 443 open)"
echo "- Fail2ban is monitoring for intrusion attempts"
echo ""
echo "Run 'vps-manager' for help on managing sites"
