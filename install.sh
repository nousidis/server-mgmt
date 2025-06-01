#!/bin/bash
# install.sh - Run this to install the VPS manager securely

set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root or with sudo"
    exit 1
fi

# Create directories
mkdir -p /usr/local/bin/{setup,php,node,database,nginx/templates,sites,utils,config/templates}
mkdir -p /etc/vps-manager/configs
mkdir -p /var/log/vps-manager

# Set ownership and permissions
chown -R root:root /usr/local/bin
chmod -R 755 /usr/local/bin
chmod -R 700 /etc/vps-manager

# Create a restricted shell script for non-root execution
cat > /usr/local/bin/vps-manager-wrapper << 'EOF'
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
EOF

chmod +x /usr/local/bin/vps-manager-wrapper

# Create alias for regular users
echo 'alias vps-manager="/usr/local/bin/vps-manager-wrapper"' >> /etc/bash.bashrc

echo "Installation complete!"
echo "Regular users can now use 'vps-manager' command"
