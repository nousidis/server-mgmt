#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Installing PostgreSQL...${NC}"

# Install PostgreSQL
apt-get install -y postgresql postgresql-contrib

# Configure authentication
PG_VERSION=$(psql --version | awk '{print $3}' | sed 's/\..*//')
sed -i "s/local   all             all                                     peer/local   all             all                                     md5/" /etc/postgresql/$PG_VERSION/main/pg_hba.conf

# Setup initial security
systemctl restart postgresql

# Set postgres user password
POSTGRES_PASSWORD=$1
if [ ! -z "$POSTGRES_PASSWORD" ]; then
    sudo -u postgres psql -c "ALTER USER postgres PASSWORD '$POSTGRES_PASSWORD';"
fi

echo -e "${GREEN}PostgreSQL installed and configured!${NC}"
