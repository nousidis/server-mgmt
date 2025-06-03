#!/bin/bash

timezone=$1
username=$2

cp -r * /usr/local/bin/
chmod +x /usr/local/bin/**/*.sh
ln -s /usr/local/bin/vps-manager.sh /usr/bin/vps-manager
/usr/local/bin/setup/00-initial-setup.sh $timezone $username
/usr/local/bin/setup/01-install-dependencies.sh
/usr/local/bin/setup/02-directory-structure.sh
