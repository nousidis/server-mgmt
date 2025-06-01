#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Setting up monitoring...${NC}"

# Install monitoring tools
apt-get install -y htop iotop iftop ncdu vnstat monit

# Configure Monit
cat > /etc/monit/monitrc << 'EOF'
set daemon 120
set log /var/log/monit.log

set mailserver localhost

set httpd port 2812 and
    use address localhost
    allow localhost

# System monitoring
check system $HOST
    if loadavg (1min) > 4 then alert
    if loadavg (5min) > 2 then alert
    if cpu usage > 95% for 10 cycles then alert
    if memory usage > 75% then alert
    if swap usage > 25% then alert

# Nginx monitoring
check process nginx with pidfile /var/run/nginx.pid
    start program = "/bin/systemctl start nginx"
    stop program = "/bin/systemctl stop nginx"
    if cpu > 60% for 2 cycles then alert
    if failed host localhost port 80 protocol http then restart
    if 3 restarts within 5 cycles then timeout

# MySQL monitoring
check process mysql with pidfile /var/run/mysqld/mysqld.pid
    start program = "/bin/systemctl start mysql"
    stop program = "/bin/systemctl stop mysql"
    if failed unixsocket /var/run/mysqld/mysqld.sock then restart
    if 3 restarts within 5 cycles then timeout

# Disk space monitoring
check filesystem rootfs with path /
    if space usage > 80% then alert
    if space usage > 90% then alert
EOF

chmod 600 /etc/monit/monitrc

# Setup log rotation
cat > /etc/logrotate.d/vps-sites << 'EOF'
/var/log/sites/*/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data adm
    sharedscripts
    postrotate
        [ -f /var/run/nginx.pid ] && kill -USR1 `cat /var/run/nginx.pid`
    endscript
}
EOF

# Start services
systemctl enable monit
systemctl start monit
systemctl enable vnstat
systemctl start vnstat

echo -e "${GREEN}Monitoring setup completed!${NC}"
