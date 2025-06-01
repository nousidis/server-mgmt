#!/bin/bash
# secure-db-setup.sh - Secure database credential management

generate_password() {
    # Generate a strong password
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

store_credentials() {
    local user=$1
    local db_name=$2
    local db_user=$3
    local db_password=$4
    local db_type=$5
    
    # Create secure credential file
    CRED_FILE="/home/$user/.db_credentials"
    
    cat > $CRED_FILE << EOF
# Database credentials for $db_name
# Generated: $(date)
DB_TYPE=$db_type
DB_NAME=$db_name
DB_USER=$db_user
DB_PASSWORD=$db_password
DB_HOST=localhost
DB_PORT=$([[ "$db_type" == "mysql" ]] && echo "3306" || echo "5432")
EOF
    
    # Secure the file
    chown $user:$user $CRED_FILE
    chmod 400 $CRED_FILE  # Read-only for owner
}

create_mysql_user_limited() {
    local db_name=$1
    local db_user=$2
    local db_password=$3
    
    mysql << EOF
-- Create database
CREATE DATABASE IF NOT EXISTS \`$db_name\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Create user with limited privileges
CREATE USER IF NOT EXISTS '$db_user'@'localhost' IDENTIFIED BY '$db_password';

-- Grant only necessary privileges
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, CREATE TEMPORARY TABLES, LOCK TABLES 
ON \`$db_name\`.* TO '$db_user'@'localhost';

-- No SUPER, FILE, or PROCESS privileges
FLUSH PRIVILEGES;
EOF
}
