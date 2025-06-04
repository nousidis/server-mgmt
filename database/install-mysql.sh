#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ROOT_PASSWORD=$1

if [ -z "$ROOT_PASSWORD" ]; then
    echo "Usage: $0 <root_password>"
    exit 1
fi

echo -e "${GREEN}Installing MySQL...${NC}"

# Set root password for unattended installation
debconf-set-selections <<< "mysql-server mysql-server/root_password password $ROOT_PASSWORD"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $ROOT_PASSWORD"

# Install MySQL
apt-get install -y mysql-server mysql-client

# Secure installation
mysql -u root -p$ROOT_PASSWORD << EOF
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

# Configure for production
cat > /etc/mysql/mysql.conf.d/production.cnf << EOF
[mysqld]
# Performance
innodb_buffer_pool_size = 256M
innodb_log_file_size = 64M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT

# Connections
max_connections = 200
connect_timeout = 10

# Cache
query_cache_type = 1
query_cache_size = 32M
query_cache_limit = 2M

# Logging
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow-query.log
long_query_time = 2
EOF

systemctl restart mysql

echo -e "${GREEN}MySQL installed and configured!${NC}"
