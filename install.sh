#!/bin/bash

set -euo pipefail

timezone=${1:-"UTC"}
username=${2:-""}

echo "Installing VPS Manager..."

# Ensure we're running as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

# Create log directory
mkdir -p /var/log
touch /var/log/vps-manager.log

# Copy scripts to system location
cp -r ./* /usr/local/bin/
find /usr/local/bin -type f -exec chmod +x {} \;

# Create the wrapper script for sudo handling
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
    echo "$username ALL=(ALL) NOPASSWD: /usr/local/bin/vps-manager.sh" > /etc/sudoers.d/vps-manager
    chmod 440 /etc/sudoers.d/vps-manager
fi

# Run setup scripts
/usr/local/bin/setup/00-initial-setup.sh "$timezone" "$username"
/usr/local/bin/setup/01-install-dependencies.sh
/usr/local/bin/setup/02-directory-structure.sh

echo "VPS Manager installation completed!"
echo "You can now use 'vps-manager' command (it will automatically handle sudo)"
