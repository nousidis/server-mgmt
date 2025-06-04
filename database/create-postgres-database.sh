#!/bin/bash
set -euo pipefail

DB_NAME=$1
DB_USER=$2
DB_PASSWORD=$3

if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
    echo "Usage: $0 <db_name> <db_user> <db_password>"
    exit 1
fi

sudo -u postgres psql << EOF
CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
CREATE DATABASE $DB_NAME OWNER $DB_USER;
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
EOF

echo "PostgreSQL database $DB_NAME created with user $DB_USER"
