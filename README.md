# VPS Manager

A comprehensive, production-ready VPS management system for managing web servers, sites, and applications.

## Features

- **Unified Command Interface**: All functionality accessible through a single `vps-manager` command
- **Site Management**: Create, remove, list, backup, and get information about sites
- **Framework Support**: Laravel, Next.js, SvelteKit, PHP, and static sites
- **Database Operations**: MySQL and PostgreSQL creation and management
- **SSL Management**: Automated Let's Encrypt integration
- **Deployment**: Git-based deployments with framework-specific build processes
- **Monitoring**: System health checks and logs

## Installation

1. Clone this repository
2. Run the installation script:

```bash
sudo ./install.sh [timezone] [username]
```

- `timezone`: Optional. Sets the server timezone (default: UTC)
- `username`: Optional. User to grant passwordless sudo access for the VPS Manager

## Usage

After installation, you can use the `vps-manager` command to access all functionality:

```bash
vps-manager <command> [subcommand] [options]
```

### Main Commands

- `site`: Manage websites (create, remove, list, info, backup)
- `deploy`: Deploy applications to sites
- `ssl`: Manage SSL certificates
- `db`: Manage databases
- `system`: System management commands
- `logs`: View and manage logs

### Site Management

```bash
# Create a new site
vps-manager site create example.com --framework=laravel --php=8.2 --database=mysql

# List all sites
vps-manager site list

# Get detailed information about a site
vps-manager site info example.com

# Backup a site
vps-manager site backup example.com

# Remove a site
vps-manager site remove example.com --backup
```

### Deployment

```bash
# Deploy from a Git repository
vps-manager deploy example.com --repo=https://github.com/user/repo.git

# Deploy a specific branch and run build process
vps-manager deploy example.com --branch=production --build
```

### SSL Management

```bash
# Enable SSL for a site
vps-manager ssl enable example.com --email=admin@example.com

# Check SSL certificate status
vps-manager ssl status example.com

# Renew SSL certificates
vps-manager ssl renew --all
```

### Database Management

```bash
# Create a new database
vps-manager db create myapp_db --type=mysql --user=myapp_user

# Backup a database
vps-manager db backup example.com

# Restore a database from backup
vps-manager db restore example.com --file=backup.sql

# List all databases
vps-manager db list
```

### System Management

```bash
# Show system status
vps-manager system status

# Update system packages
vps-manager system update

# Run health checks
vps-manager system health
```

### Logs Management

```bash
# Tail logs for a site
vps-manager logs tail example.com --lines=100 --type=error

# View logs
vps-manager logs view example.com --type=access

# Clear logs
vps-manager logs clear example.com --type=all
```

## Command Options

Most commands support both interactive and non-interactive modes. When run without required parameters, the command will prompt for input. When run with all required parameters, it will execute without prompts.

Options can be provided in the format `--option=value` or `--flag` for boolean options.

## Directory Structure

```
/usr/local/bin/vps-manager/
├── vps-manager.sh          # Main entry point
├── vps-manager-core.sh     # Core functions and utilities
├── database/               # Database management scripts
├── nginx/                  # Nginx configuration scripts
├── node/                   # Node.js management scripts
├── php/                    # PHP management scripts
├── sites/                  # Site management scripts
├── utils/                  # Utility scripts
└── config/                 # Configuration templates
```

## License

MIT
