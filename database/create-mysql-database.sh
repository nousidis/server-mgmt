#!/bin/bash

set -euo pipefail

DB_NAME=$1
DB_USER=$2
DB_PASSWORD=$3

if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
    echo "Usage: $0 <db_name> <db_user> <db_password>"
    exit 1
fi

# Read root password securely
if [ -f /root/.mysql_root_password ]; then
    ROOT_PASSWORD=$(cat /root/.mysql_root_password)
else
    echo "MySQL root password file not found at /root/.mysql_root_password"
    exit 1
fi

# Create temporary SQL file to avoid password in command history
TEMP_SQL=$(mktemp)
cat > "$TEMP_SQL" << EOF
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
GRANT USAGE ON *.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

# Execute SQL
if mysql -u root -p"$ROOT_PASSWORD" < "$TEMP_SQL"; then
    echo "MySQL database $DB_NAME created with user $DB_USER"
    rm -f "$TEMP_SQL"
else
    echo "Failed to create MySQL database"
    rm -f "$TEMP_SQL"
    exit 1
fi
