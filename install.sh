#!/bin/bash
# VPS Manager Installation Script
# This script installs and configures the VPS Manager system

set -euo pipefail

# Default values
timezone=${1:-"UTC"}
username=${2:-""}
version="1.0.0"

echo -e "\033[0;34m"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                 VPS Manager Installation                  ║"
echo "║                      Version $version                       ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "\033[0m"

# Ensure we're running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "\033[0;31mThis script must be run as root\033[0m"
    exit 1
fi

# Create required directories
echo "Creating required directories..."
mkdir -p /var/log
mkdir -p /var/backups/sites
mkdir -p /var/backups/databases
mkdir -p /etc/vps-manager/configs
mkdir -p /usr/local/bin/lib
touch /var/log/vps-manager.log

# Copy scripts to system location
echo "Copying scripts to system location..."
cp -r ./database /usr/local/bin/
cp -r ./nginx /usr/local/bin/
cp -r ./node /usr/local/bin/
cp -r ./php /usr/local/bin/
cp -r ./setup /usr/local/bin/
cp -r ./sites /usr/local/bin/
cp -r ./utils /usr/local/bin/
cp -r ./config /usr/local/bin/

# Make all scripts executable
echo "Setting executable permissions..."
find /usr/local/bin -type f -name "*.sh" -exec chmod +x {} \;

# Copy main scripts
cp ./vps-manager.sh /usr/local/bin/
cp ./vps-manager-core.sh /usr/local/bin/
chmod +x /usr/local/bin/vps-manager*.sh

# Create the wrapper script for sudo handling
echo "Creating command wrapper..."
cat > /usr/bin/vps-manager << 'EOF'
#!/bin/bash
# VPS Manager wrapper - handles sudo automatically

if [ "$EUID" -ne 0 ]; then
    exec sudo /usr/local/bin/vps-manager.sh "$@"
else
    exec /usr/local/bin/vps-manager.sh "$@"
fi
EOF

chmod +x /usr/bin/vps-manager

# Setup sudoers entry for passwordless execution (optional)
if [ ! -z "$username" ]; then
    echo "Setting up passwordless sudo for $username..."
    echo "$username ALL=(ALL) NOPASSWD: /usr/local/bin/vps-manager.sh" > /etc/sudoers.d/vps-manager
    chmod 440 /etc/sudoers.d/vps-manager
fi

# Run setup scripts
echo "Running initial setup scripts..."
/usr/local/bin/setup/00-initial-setup.sh "$timezone" "$username"
/usr/local/bin/setup/01-install-dependencies.sh
/usr/local/bin/setup/02-directory-structure.sh

# Create configuration file
echo "Creating configuration file..."
cat > /etc/vps-manager/config.json << EOF
{
    "version": "$version",
    "installed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "timezone": "$timezone",
    "admin_user": "$username"
}
EOF

# Log installation
echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] VPS Manager v$version installed successfully" >> /var/log/vps-manager.log

echo -e "\033[0;32m"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║             VPS Manager Installation Complete             ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "\033[0m"
echo "You can now use the 'vps-manager' command to manage your server."
echo ""
echo "Examples:"
echo "  vps-manager site create example.com --framework=laravel --php=8.2 --database=mysql"
echo "  vps-manager deploy example.com --repo=https://github.com/user/repo.git"
echo "  vps-manager ssl enable example.com --email=admin@example.com"
echo "  vps-manager system status"
echo ""
echo "For more information, run: vps-manager --help"
