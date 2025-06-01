#!/bin/bash

DB_NAME=$1
DB_USER=$2
DB_PASSWORD=$3
ROOT_PASSWORD=$4

if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ] || [ -z "$ROOT_PASSWORD" ]; then
    echo "Usage: $0 <db_name> <db_user> <db_password> <root_password>"
    exit 1
fi

mysql -u root -p$ROOT_PASSWORD << EOF
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
GRANT USAGE ON *.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

echo "MySQL database $DB_NAME created with user $DB_USER"
