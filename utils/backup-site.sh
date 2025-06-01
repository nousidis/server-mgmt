#!/bin/bash

DOMAIN=$1
BACKUP_DB=$2

if [ -z "$DOMAIN" ]; then
    echo "Usage: $0 <domain> [backup_db:yes/no]"
    exit 1
fi

BACKUP_DB=${BACKUP_DB:-"yes"}

# Get site info
if [ ! -f "/etc/vps-manager/configs/$DOMAIN.json" ]; then
    echo "Site configuration not found for $DOMAIN"
    exit 1
fi

USER=$(jq -r '.user' /etc/vps-manager/configs/$DOMAIN.json)
DB_TYPE=$(jq -r '.db_type' /etc/vps-manager/configs/$DOMAIN.json)

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/var/backups/sites/$DOMAIN"
mkdir -p $BACKUP_DIR

# Backup files
echo "Backing up files..."
tar -czf $BACKUP_DIR/files_$TIMESTAMP.tar.gz -C /var/www $DOMAIN

# Backup database
if [ "$BACKUP_DB" == "yes" ] && [ "$DB_TYPE" != "none" ] && [ "$DB_TYPE" != "null" ]; then
    if [ -f "/home/$USER/.db_credentials" ]; then
        source /home/$USER/.db_credentials
        
        echo "Backing up database..."
        if [ "$DB_TYPE" == "mysql" ]; then
            mysqldump -u $DB_USER -p$DB_PASSWORD $DB_NAME | gzip > $BACKUP_DIR/database_$TIMESTAMP.sql.gz
        elif [ "$DB_TYPE" == "postgres" ]; then
            PGPASSWORD=$DB_PASSWORD pg_dump -U $DB_USER -h localhost $DB_NAME | gzip > $BACKUP_DIR/database_$TIMESTAMP.sql.gz
        fi
    fi
fi

# Create combined backup
tar -czf $BACKUP_DIR/full_backup_$TIMESTAMP.tar.gz \
    $BACKUP_DIR/files_$TIMESTAMP.tar.gz \
    $BACKUP_DIR/database_$TIMESTAMP.sql.gz 2>/dev/null

# Cleanup individual files
rm -f $BACKUP_DIR/files_$TIMESTAMP.tar.gz
rm -f $BACKUP_DIR/database_$TIMESTAMP.sql.gz

echo "Backup completed: $BACKUP_DIR/full_backup_$TIMESTAMP.tar.gz"

# Cleanup old backups (keep last 7)
cd $BACKUP_DIR
ls -t full_backup_*.tar.gz | tail -n +8 | xargs rm -f 2>/dev/null
