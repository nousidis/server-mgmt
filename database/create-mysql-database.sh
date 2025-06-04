#!/bin/bash

set -euo pipefail

DB_NAME=$1
DB_USER=$2
DB_PASSWORD=$3

if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
    echo "Usage: $0 <db_name> <db_user> <db_password>"
    exit 1
fi

# Try to get MySQL root password from different sources
get_mysql_root_password() {
    # Check for password file
    if [ -f /root/.mysql_root_password ]; then
        cat /root/.mysql_root_password
        return 0
    fi
    
    # Check environment variable
    if [ ! -z "${MYSQL_ROOT_PASSWORD:-}" ]; then
        echo "$MYSQL_ROOT_PASSWORD"
        return 0
    fi
    
    # Try to connect without password (some installations)
    if mysql -u root -e "SELECT 1" &>/dev/null; then
        echo ""
        return 0
    fi
    
    # Prompt for password
    read -sp "Enter MySQL root password: " ROOT_PASSWORD
    echo >&2  # New line after password input
    echo "$ROOT_PASSWORD"
    
    # Optionally save for future use
    read -p "Save password for future use? (y/n): " SAVE
    if [[ "$SAVE" == "y" ]]; then
        echo "$ROOT_PASSWORD" > /root/.mysql_root_password
        chmod 600 /root/.mysql_root_password
    fi
}

# Get root password
ROOT_PASSWORD=$(get_mysql_root_password)

# Create temporary SQL file
TEMP_SQL=$(mktemp)
cat > "$TEMP_SQL" << EOF
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
GRANT USAGE ON *.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

# Execute SQL
if [ -z "$ROOT_PASSWORD" ]; then
    # Try without password
    if mysql -u root < "$TEMP_SQL" 2>/dev/null; then
        echo "MySQL database $DB_NAME created with user $DB_USER"
    else
        echo "Failed to create MySQL database - authentication required"
        rm -f "$TEMP_SQL"
        exit 1
    fi
else
    # Try with password
    if mysql -u root -p"$ROOT_PASSWORD" < "$TEMP_SQL"; then
        echo "MySQL database $DB_NAME created with user $DB_USER"
    else
        echo "Failed to create MySQL database - check root password"
        rm -f "$TEMP_SQL"
        exit 1
    fi
fi

rm -f "$TEMP_SQL"
