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
grep "Failed password" /var/log/auth.log | tail -10
echo ""

# Check firewall status
echo "Firewall status:"
ufw status
echo ""

# Check for updates
echo "Security updates available:"
apt list --upgradable 2>/dev/null | grep -i security
