#!/bin/bash
# Run this ONCE when you first get your VPS

# Create a management user
ADMIN_USER="vpsadmin"  # Change this to your preferred username
ADMIN_PASSWORD=$(openssl rand -base64 32)

# Create the user
useradd -m -s /bin/bash $ADMIN_USER
echo "$ADMIN_USER:$ADMIN_PASSWORD" | chpasswd

# Add to sudo group
usermod -aG sudo $ADMIN_USER

# Configure sudo without password for specific commands
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
EOF

# Set proper permissions
chmod 440 /etc/sudoers.d/vps-manager

# Copy SSH keys if they exist
if [ -d /root/.ssh ]; then
    cp -r /root/.ssh /home/$ADMIN_USER/
    chown -R $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/.ssh
    chmod 700 /home/$ADMIN_USER/.ssh
    chmod 600 /home/$ADMIN_USER/.ssh/authorized_keys
fi

echo "Admin user created: $ADMIN_USER"
echo "Temporary password: $ADMIN_PASSWORD"
echo "Please login and change this password immediately!"

# Create the directory structure
mkdir -p /usr/local/bin/{setup,php,node,database,nginx/templates,sites,utils,config/templates}

cp -r * /usr/local/bin/*

# Make them all executable
chmod -R +x /usr/local/bin/

# Run the enhanced security setup FIRST
./initial-security-setup.sh  # This creates vpsadmin user

# Run the secure installation script
./install.sh  # This sets up permissions and sudo rules
