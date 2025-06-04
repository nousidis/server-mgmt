#!/bin/bash

# VPS Manager - Main entry point for the VPS Management System
# This script integrates all functionality into a unified command interface

# Source the core functions
source /usr/local/bin/vps-manager-core.sh

# ===== SITE MANAGEMENT FUNCTIONS =====

# Create a new site
site_create() {
    log "INFO" "Starting site creation process"

    # Parse arguments
    parse_args "$@"

    # Get domain (either from first argument or prompt)
    local domain="${ARGS[1]:-}"
    if [ -z "$domain" ]; then
        while true; do
            read -p "Domain name: " domain
            if validate_domain "$domain"; then
                break
            else
                echo -e "${RED}Invalid domain format${NC}"
            fi
        done
    else
        if ! validate_domain "$domain"; then
            error_exit "Invalid domain format: $domain"
        fi
    fi

    # Check if site already exists
    if site_exists "$domain"; then
        error_exit "Site already exists: $domain"
    fi

    # Get framework (either from option or prompt)
    local framework=$(get_opt "framework" "${ARGS[2]:-}")
    if [ -z "$framework" ]; then
        echo "Framework options: laravel, php, nextjs, sveltekit, static"
        while true; do
            read -p "Framework: " framework
            if validate_framework "$framework"; then
                break
            else
                echo -e "${RED}Invalid framework${NC}"
                echo "Valid options: laravel, php, nextjs, sveltekit, static"
            fi
        done
    else
        if ! validate_framework "$framework"; then
            error_exit "Invalid framework: $framework"
        fi
    fi

    # Get PHP version for PHP frameworks
    local php_version=""
    if [[ "$framework" == "laravel" || "$framework" == "php" ]]; then
        php_version=$(get_opt "php" "${ARGS[3]:-}")
        if [ -z "$php_version" ]; then
            while true; do
                read -p "PHP version (7.4/8.0/8.1/8.2/8.3) [8.2]: " php_version
                php_version=${php_version:-"8.2"}
                if validate_php_version "$php_version"; then
                    break
                else
                    echo -e "${RED}Invalid PHP version${NC}"
                    echo "Valid options: 7.4, 8.0, 8.1, 8.2, 8.3"
                fi
            done
        else
            if ! validate_php_version "$php_version"; then
                error_exit "Invalid PHP version: $php_version"
            fi
        fi
    fi

    # Get database type
    local db_type=$(get_opt "database" "${ARGS[4]:-}")
    if [ -z "$db_type" ]; then
        echo "Database options: mysql, postgres, none"
        read -p "Database type [none]: " db_type
        db_type=${db_type:-"none"}
    fi
    if ! validate_db_type "$db_type"; then
        error_exit "Invalid database type: $db_type"
    fi

    # Get Git repository
    local git_repo=$(get_opt "repo" "${ARGS[5]:-}")
    if [ -z "$git_repo" ] && [ -z "${ARGS[5]:-}" ]; then
        read -p "Git repository (optional): " git_repo
    fi

    # Log the action
    log "INFO" "Creating site: $domain with framework: $framework, PHP: $php_version, DB: $db_type"

    # Execute with error handling
    if $SCRIPT_DIR/sites/create-site.sh "$domain" "$framework" "$php_version" "$db_type" "$git_repo"; then
        success "Site created successfully: $domain"
    else
        error_exit "Failed to create site: $domain"
    fi
}

# Remove a site
site_remove() {
    log "INFO" "Starting site removal process"

    # Parse arguments
    parse_args "$@"

    # Get domain (either from first argument or prompt)
    local domain="${ARGS[1]:-}"
    if [ -z "$domain" ]; then
        while true; do
            read -p "Domain name to remove: " domain
            if validate_domain "$domain"; then
                break
            else
                echo -e "${RED}Invalid domain format${NC}"
            fi
        done
    else
        if ! validate_domain "$domain"; then
            error_exit "Invalid domain format: $domain"
        fi
    fi

    # Check if site exists
    if ! site_exists "$domain"; then
        error_exit "Site does not exist: $domain"
    fi

    # Confirm removal
    if ! has_opt "force"; then
        read -p "Are you sure you want to remove $domain? This cannot be undone. [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "Operation cancelled"
            return 0
        fi
    fi

    # Check if backup is requested
    local backup_flag="no"
    if has_opt "backup"; then
        backup_flag="yes"

        # Backup the site first
        local backup_file=$(backup_site "$domain")
        if [ $? -eq 0 ]; then
            success "Site backed up to: $backup_file"
        else
            warn "Failed to backup site before removal"

            # Confirm continuation without backup
            read -p "Continue with removal without backup? [y/N]: " confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                echo "Operation cancelled"
                return 0
            fi
        fi
    fi

    # Remove database?
    local remove_db="no"
    if has_opt "remove-db"; then
        remove_db="yes"
    else
        read -p "Remove associated database? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            remove_db="yes"
        fi
    fi

    # Log the action
    log "INFO" "Removing site: $domain (remove_db: $remove_db)"

    # Execute with error handling
    if $SCRIPT_DIR/sites/remove-site.sh "$domain" "$remove_db"; then
        success "Site removed successfully: $domain"
    else
        error_exit "Failed to remove site: $domain"
    fi
}

# List all sites
site_list() {
    log "INFO" "Listing all sites"

    echo -e "${BLUE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│                    Configured Sites                         │${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    local count=0
    for config in $CONFIG_DIR/configs/*.json; do
        if [ -f "$config" ]; then
            ((count++))
            local domain=$(jq -r '.domain' "$config")
            local framework=$(jq -r '.framework' "$config")
            local user=$(jq -r '.user' "$config")
            local php_version=$(jq -r '.php_version // "N/A"' "$config")
            local db_type=$(jq -r '.db_type // "none"' "$config")
            local created=$(jq -r '.created' "$config")

            echo -e "${GREEN}[$count] $domain${NC}"
            echo "    ├─ Framework: $framework"
            echo "    ├─ User: $user"
            [[ "$php_version" != "N/A" && "$php_version" != "null" ]] && echo "    ├─ PHP: $php_version"
            [[ "$db_type" != "none" && "$db_type" != "null" ]] && echo "    ├─ Database: $db_type"
            echo "    └─ Created: $created"
            echo ""
        fi
    done

    if [ $count -eq 0 ]; then
        echo -e "${YELLOW}No sites configured${NC}"
    else
        echo -e "${BLUE}Total sites: $count${NC}"
    fi
}

# Show detailed site information
site_info() {
    log "INFO" "Showing site information"

    # Parse arguments
    parse_args "$@"

    # Get domain (either from first argument or prompt)
    local domain="${ARGS[1]:-}"
    if [ -z "$domain" ]; then
        while true; do
            read -p "Domain name: " domain
            if validate_domain "$domain"; then
                break
            else
                echo -e "${RED}Invalid domain format${NC}"
            fi
        done
    else
        if ! validate_domain "$domain"; then
            error_exit "Invalid domain format: $domain"
        fi
    fi

    # Check if site exists
    if ! site_exists "$domain"; then
        error_exit "Site does not exist: $domain"
    fi

    # Load site configuration
    load_site_config "$domain"

    # Display site information
    echo -e "${BLUE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│                 Site Information: $domain                   │${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${GREEN}Domain:${NC} $SITE_DOMAIN"
    echo -e "${GREEN}Framework:${NC} $SITE_FRAMEWORK"
    echo -e "${GREEN}User:${NC} $SITE_USER"

    if [[ "$SITE_PHP_VERSION" != "null" ]]; then
        echo -e "${GREEN}PHP Version:${NC} $SITE_PHP_VERSION"
    fi

    if [[ "$SITE_DB_TYPE" != "none" ]]; then
        echo -e "${GREEN}Database Type:${NC} $SITE_DB_TYPE"
        if [[ -n "${DB_NAME:-}" ]]; then
            echo -e "${GREEN}Database Name:${NC} $DB_NAME"
            echo -e "${GREEN}Database User:${NC} $DB_USER"
        fi
    fi

    if [[ "$SITE_PORT" != "null" ]]; then
        echo -e "${GREEN}Port:${NC} $SITE_PORT"
    fi

    echo -e "${GREEN}Created:${NC} $SITE_CREATED"
    echo -e "${GREEN}Last Updated:${NC} $SITE_UPDATED"

    # Check if site is accessible
    if curl -s -I "http://$domain" &>/dev/null; then
        echo -e "${GREEN}Status:${NC} Online"
    else
        echo -e "${GREEN}Status:${NC} Offline or not accessible"
    fi

    # Check SSL status
    if curl -s -I "https://$domain" &>/dev/null; then
        echo -e "${GREEN}SSL:${NC} Enabled"
    else
        echo -e "${GREEN}SSL:${NC} Disabled or not configured"
    fi

    # Display directory information
    echo ""
    echo -e "${BLUE}Directory Information:${NC}"
    echo -e "Web Root: /var/www/$domain"
    echo -e "Logs: /var/log/sites/$domain"

    # Display Nginx configuration
    if [ -f "/etc/nginx/sites-available/$domain" ]; then
        echo ""
        echo -e "${BLUE}Nginx Configuration:${NC} /etc/nginx/sites-available/$domain"
    fi

    # Display PHP-FPM pool configuration
    if [[ "$SITE_PHP_VERSION" != "null" ]] && [ -f "/etc/php/$SITE_PHP_VERSION/fpm/pool.d/$domain.conf" ]; then
        echo -e "${BLUE}PHP-FPM Pool:${NC} /etc/php/$SITE_PHP_VERSION/fpm/pool.d/$domain.conf"
    fi
}

# Backup a site
site_backup() {
    log "INFO" "Starting site backup process"

    # Parse arguments
    parse_args "$@"

    # Get domain (either from first argument or prompt)
    local domain="${ARGS[1]:-}"
    if [ -z "$domain" ]; then
        while true; do
            read -p "Domain name to backup: " domain
            if validate_domain "$domain"; then
                break
            else
                echo -e "${RED}Invalid domain format${NC}"
            fi
        done
    else
        if ! validate_domain "$domain"; then
            error_exit "Invalid domain format: $domain"
        fi
    fi

    # Check if site exists
    if ! site_exists "$domain"; then
        error_exit "Site does not exist: $domain"
    fi

    # Get backup directory (optional)
    local backup_dir=$(get_opt "dir" "$BACKUP_DIR")

    # Execute backup
    local backup_file=$(backup_site "$domain" "$backup_dir")
    if [ $? -eq 0 ]; then
        success "Site backed up successfully to: $backup_file"
    else
        error_exit "Failed to backup site: $domain"
    fi
}

# ===== DEPLOYMENT FUNCTIONS =====

# Deploy to a site
deploy() {
    log "INFO" "Starting deployment process"

    # Parse arguments
    parse_args "$@"

    # Get domain (either from first argument or prompt)
    local domain="${ARGS[1]:-}"
    if [ -z "$domain" ]; then
        while true; do
            read -p "Domain name to deploy to: " domain
            if validate_domain "$domain"; then
                break
            else
                echo -e "${RED}Invalid domain format${NC}"
            fi
        done
    else
        if ! validate_domain "$domain"; then
            error_exit "Invalid domain format: $domain"
        fi
    fi

    # Check if site exists
    if ! site_exists "$domain"; then
        error_exit "Site does not exist: $domain"
    fi

    # Load site configuration
    load_site_config "$domain"

    # Get repository URL
    local repo=$(get_opt "repo" "${ARGS[2]:-}")
    if [ -z "$repo" ] && [ -z "${ARGS[2]:-}" ]; then
        read -p "Git repository URL: " repo
    fi

    # Validate repository URL if provided
    if [ ! -z "$repo" ]; then
        if ! validate_url "$repo"; then
            error_exit "Invalid repository URL: $repo"
        fi
    fi

    # Get branch
    local branch=$(get_opt "branch" "main")

    # Should we run build process?
    local build=false
    if has_opt "build"; then
        build=true
    fi

    # Log the action
    log "INFO" "Deploying to site: $domain from repo: $repo, branch: $branch, build: $build"

    # Execute deployment based on framework
    case "$SITE_FRAMEWORK" in
        laravel)
            if $SCRIPT_DIR/sites/deploy-laravel.sh "$domain" "$repo" "$branch" "$build"; then
                success "Laravel application deployed successfully to: $domain"
            else
                error_exit "Failed to deploy Laravel application to: $domain"
            fi
            ;;
        nextjs)
            if $SCRIPT_DIR/sites/deploy-nextjs.sh "$domain" "$repo" "$branch" "$build"; then
                success "Next.js application deployed successfully to: $domain"
            else
                error_exit "Failed to deploy Next.js application to: $domain"
            fi
            ;;
        sveltekit)
            if $SCRIPT_DIR/sites/deploy-sveltekit.sh "$domain" "$repo" "$branch" "$build"; then
                success "SvelteKit application deployed successfully to: $domain"
            else
                error_exit "Failed to deploy SvelteKit application to: $domain"
            fi
            ;;
        *)
            # Generic deployment for other frameworks
            if [ -z "$repo" ]; then
                error_exit "Repository URL is required for deployment"
            fi

            # Clone repository
            log "INFO" "Cloning repository: $repo to /var/www/$domain"
            if run_as_user "$SITE_USER" "cd /var/www/$domain && git clone $repo . -b $branch"; then
                success "Repository cloned successfully"
            else
                error_exit "Failed to clone repository"
            fi

            # Run build process if requested
            if [ "$build" = true ]; then
                log "INFO" "Running build process"
                if [ -f "/var/www/$domain/package.json" ]; then
                    run_as_user "$SITE_USER" "cd /var/www/$domain && npm install && npm run build"
                elif [ -f "/var/www/$domain/composer.json" ]; then
                    run_as_user "$SITE_USER" "cd /var/www/$domain && composer install --no-dev --optimize-autoloader"
                else
                    warn "No package.json or composer.json found, skipping build process"
                fi
            fi

            success "Deployment completed for: $domain"
            ;;
    esac
}

# ===== SSL MANAGEMENT FUNCTIONS =====

# SSL management
ssl() {
    log "INFO" "Starting SSL management process"

    # Parse arguments
    parse_args "$@"

    # Get subcommand
    local subcommand="${ARGS[1]:-}"
    if [ -z "$subcommand" ]; then
        show_ssl_help
        return 0
    fi

    case "$subcommand" in
        enable)
            ssl_enable "${ARGS[@]:1}"
            ;;
        disable)
            ssl_disable "${ARGS[@]:1}"
            ;;
        renew)
            ssl_renew "${ARGS[@]:1}"
            ;;
        status)
            ssl_status "${ARGS[@]:1}"
            ;;
        --help)
            show_ssl_help
            ;;
        *)
            error_exit "Unknown SSL subcommand: $subcommand"
            ;;
    esac
}

# Enable SSL for a site
ssl_enable() {
    # Parse arguments
    parse_args "$@"

    # Get domain (either from first argument or prompt)
    local domain="${ARGS[1]:-}"
    if [ -z "$domain" ]; then
        while true; do
            read -p "Domain name: " domain
            if validate_domain "$domain"; then
                break
            else
                echo -e "${RED}Invalid domain format${NC}"
            fi
        done
    else
        if ! validate_domain "$domain"; then
            error_exit "Invalid domain format: $domain"
        fi
    fi

    # Check if site exists
    if ! site_exists "$domain"; then
        error_exit "Site does not exist: $domain"
    fi

    # Get email address
    local email=$(get_opt "email" "")
    if [ -z "$email" ]; then
        while true; do
            read -p "Email address for SSL notifications: " email
            if validate_email "$email"; then
                break
            else
                echo -e "${RED}Invalid email format${NC}"
            fi
        done
    else
        if ! validate_email "$email"; then
            error_exit "Invalid email format: $email"
        fi
    fi

    # Log the action
    log "INFO" "Enabling SSL for site: $domain with email: $email"

    # Execute SSL setup
    if $SCRIPT_DIR/nginx/ssl-setup.sh "$domain" "$email"; then
        success "SSL enabled successfully for: $domain"
    else
        error_exit "Failed to enable SSL for: $domain"
    fi
}

# Disable SSL for a site
ssl_disable() {
    # Parse arguments
    parse_args "$@"

    # Get domain (either from first argument or prompt)
    local domain="${ARGS[1]:-}"
    if [ -z "$domain" ]; then
        while true; do
            read -p "Domain name: " domain
            if validate_domain "$domain"; then
                break
            else
                echo -e "${RED}Invalid domain format${NC}"
            fi
        done
    else
        if ! validate_domain "$domain"; then
            error_exit "Invalid domain format: $domain"
        fi
    fi

    # Check if site exists
    if ! site_exists "$domain"; then
        error_exit "Site does not exist: $domain"
    fi

    # Check if SSL is enabled
    if [ ! -f "/etc/nginx/sites-available/$domain" ] || ! grep -q "ssl_certificate" "/etc/nginx/sites-available/$domain"; then
        error_exit "SSL is not enabled for: $domain"
    fi

    # Log the action
    log "INFO" "Disabling SSL for site: $domain"

    # Modify Nginx configuration to remove SSL
    sed -i '/ssl_certificate/d' "/etc/nginx/sites-available/$domain"
    sed -i '/ssl_certificate_key/d' "/etc/nginx/sites-available/$domain"
    sed -i '/listen 443/d' "/etc/nginx/sites-available/$domain"
    sed -i '/ssl/d' "/etc/nginx/sites-available/$domain"

    # Reload Nginx
    if nginx -t && systemctl reload nginx; then
        success "SSL disabled successfully for: $domain"
    else
        error_exit "Failed to disable SSL for: $domain"
    fi
}

# Renew SSL certificates
ssl_renew() {
    # Parse arguments
    parse_args "$@"

    # Check if we should renew all certificates
    local all=false
    if has_opt "all"; then
        all=true
    fi

    # Get domain (either from first argument or prompt)
    local domain="${ARGS[1]:-}"
    if [ "$all" = false ] && [ -z "$domain" ]; then
        while true; do
            read -p "Domain name: " domain
            if validate_domain "$domain"; then
                break
            else
                echo -e "${RED}Invalid domain format${NC}"
            fi
        done
    fi

    # Log the action
    if [ "$all" = true ]; then
        log "INFO" "Renewing all SSL certificates"

        # Renew all certificates
        if certbot renew; then
            success "All SSL certificates renewed successfully"
        else
            error_exit "Failed to renew SSL certificates"
        fi
    else
        # Check if site exists
        if ! site_exists "$domain"; then
            error_exit "Site does not exist: $domain"
        fi

        log "INFO" "Renewing SSL certificate for site: $domain"

        # Renew specific certificate
        if certbot certonly --nginx -d "$domain" --non-interactive; then
            success "SSL certificate renewed successfully for: $domain"
        else
            error_exit "Failed to renew SSL certificate for: $domain"
        fi
    fi
}

# Check SSL certificate status
ssl_status() {
    # Parse arguments
    parse_args "$@"

    # Get domain (either from first argument or prompt)
    local domain="${ARGS[1]:-}"
    if [ -z "$domain" ]; then
        while true; do
            read -p "Domain name: " domain
            if validate_domain "$domain"; then
                break
            else
                echo -e "${RED}Invalid domain format${NC}"
            fi
        done
    else
        if ! validate_domain "$domain"; then
            error_exit "Invalid domain format: $domain"
        fi
    fi

    # Check if site exists
    if ! site_exists "$domain"; then
        error_exit "Site does not exist: $domain"
    fi

    # Log the action
    log "INFO" "Checking SSL certificate status for site: $domain"

    # Check if SSL is enabled
    if [ ! -f "/etc/nginx/sites-available/$domain" ] || ! grep -q "ssl_certificate" "/etc/nginx/sites-available/$domain"; then
        echo -e "${YELLOW}SSL is not enabled for: $domain${NC}"
        return 0
    fi

    # Get certificate path
    local cert_path=$(grep "ssl_certificate " "/etc/nginx/sites-available/$domain" | awk '{print $2}' | sed 's/;$//')

    if [ -z "$cert_path" ]; then
        error_exit "Could not find SSL certificate path for: $domain"
    fi

    # Check certificate expiration
    local expiry=$(openssl x509 -enddate -noout -in "$cert_path" | cut -d= -f2)
    local expiry_date=$(date -d "$expiry" +%s)
    local current_date=$(date +%s)
    local days_left=$(( ($expiry_date - $current_date) / 86400 ))

    echo -e "${BLUE}SSL Certificate Status for: $domain${NC}"
    echo -e "${GREEN}Certificate Path:${NC} $cert_path"
    echo -e "${GREEN}Expiry Date:${NC} $expiry"
    echo -e "${GREEN}Days Until Expiry:${NC} $days_left"

    if [ $days_left -lt 7 ]; then
        echo -e "${RED}WARNING: Certificate will expire soon!${NC}"
    elif [ $days_left -lt 30 ]; then
        echo -e "${YELLOW}NOTICE: Certificate will expire in less than 30 days${NC}"
    else
        echo -e "${GREEN}Certificate is valid${NC}"
    fi
}

# ===== DATABASE MANAGEMENT FUNCTIONS =====

# Database management
db() {
    log "INFO" "Starting database management process"

    # Parse arguments
    parse_args "$@"

    # Get subcommand
    local subcommand="${ARGS[1]:-}"
    if [ -z "$subcommand" ]; then
        show_db_help
        return 0
    fi

    case "$subcommand" in
        create)
            db_create "${ARGS[@]:1}"
            ;;
        backup)
            db_backup "${ARGS[@]:1}"
            ;;
        restore)
            db_restore "${ARGS[@]:1}"
            ;;
        list)
            db_list "${ARGS[@]:1}"
            ;;
        --help)
            show_db_help
            ;;
        *)
            error_exit "Unknown database subcommand: $subcommand"
            ;;
    esac
}

# Create a new database
db_create() {
    # Parse arguments
    parse_args "$@"

    # Get database name
    local db_name="${ARGS[1]:-}"
    if [ -z "$db_name" ]; then
        read -p "Database name: " db_name
    fi

    # Get database type
    local db_type=$(get_opt "type" "mysql")
    if ! validate_db_type "$db_type" || [ "$db_type" == "none" ]; then
        error_exit "Invalid database type: $db_type"
    fi

    # Get database user
    local db_user=$(get_opt "user" "${db_name}_user")

    # Generate password
    local db_password=$(generate_password)

    # Log the action
    log "INFO" "Creating database: $db_name of type: $db_type with user: $db_user"

    # Execute database creation
    case "$db_type" in
        mysql)
            if $SCRIPT_DIR/database/create-mysql-database.sh "$db_name" "$db_user" "$db_password"; then
                success "MySQL database created successfully: $db_name"
                echo -e "${GREEN}Database credentials:${NC}"
                echo "DB_TYPE=mysql"
                echo "DB_NAME=$db_name"
                echo "DB_USER=$db_user"
                echo "DB_PASSWORD=$db_password"
                echo "DB_HOST=localhost"
                echo "DB_PORT=3306"
            else
                error_exit "Failed to create MySQL database: $db_name"
            fi
            ;;
        postgres)
            if $SCRIPT_DIR/database/create-postgres-database.sh "$db_name" "$db_user" "$db_password"; then
                success "PostgreSQL database created successfully: $db_name"
                echo -e "${GREEN}Database credentials:${NC}"
                echo "DB_TYPE=postgres"
                echo "DB_NAME=$db_name"
                echo "DB_USER=$db_user"
                echo "DB_PASSWORD=$db_password"
                echo "DB_HOST=localhost"
                echo "DB_PORT=5432"
            else
                error_exit "Failed to create PostgreSQL database: $db_name"
            fi
            ;;
    esac
}

# Backup a database
db_backup() {
    # Parse arguments
    parse_args "$@"

    # Get domain or database name
    local identifier="${ARGS[1]:-}"
    if [ -z "$identifier" ]; then
        read -p "Domain or database name: " identifier
    fi

    # Check if it's a domain
    local is_domain=false
    local db_type=""
    local db_name=""
    local db_user=""
    local db_password=""

    if validate_domain "$identifier" && site_exists "$identifier"; then
        is_domain=true
        load_site_config "$identifier"

        if [ "$SITE_DB_TYPE" == "none" ] || [ -z "${DB_NAME:-}" ]; then
            error_exit "No database associated with site: $identifier"
        fi

        db_type="$SITE_DB_TYPE"
        db_name="$DB_NAME"
        db_user="$DB_USER"
        db_password="$DB_PASSWORD"
    else
        # Assume it's a database name
        # Try to determine the database type
        if mysql -u root -e "SHOW DATABASES LIKE '$identifier'" 2>/dev/null | grep -q "$identifier"; then
            db_type="mysql"
            db_name="$identifier"
        elif sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$identifier"; then
            db_type="postgres"
            db_name="$identifier"
        else
            error_exit "Database not found: $identifier"
        fi
    fi

    # Get backup directory
    local backup_dir=$(get_opt "dir" "/var/backups/databases")
    mkdir -p "$backup_dir"

    # Generate backup filename
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$backup_dir/${db_name}_${timestamp}.sql"

    # Log the action
    log "INFO" "Backing up database: $db_name of type: $db_type"

    # Execute backup
    case "$db_type" in
        mysql)
            if mysqldump -u root "$db_name" > "$backup_file"; then
                success "MySQL database backed up successfully to: $backup_file"
            else
                error_exit "Failed to backup MySQL database: $db_name"
            fi
            ;;
        postgres)
            if sudo -u postgres pg_dump "$db_name" > "$backup_file"; then
                success "PostgreSQL database backed up successfully to: $backup_file"
            else
                error_exit "Failed to backup PostgreSQL database: $db_name"
            fi
            ;;
    esac

    # Compress the backup
    gzip -f "$backup_file"
    success "Database backup compressed: ${backup_file}.gz"
}

# Restore a database
db_restore() {
    # Parse arguments
    parse_args "$@"

    # Get domain or database name
    local identifier="${ARGS[1]:-}"
    if [ -z "$identifier" ]; then
        read -p "Domain or database name to restore to: " identifier
    fi

    # Check if it's a domain
    local is_domain=false
    local db_type=""
    local db_name=""
    local db_user=""
    local db_password=""

    if validate_domain "$identifier" && site_exists "$identifier"; then
        is_domain=true
        load_site_config "$identifier"

        if [ "$SITE_DB_TYPE" == "none" ] || [ -z "${DB_NAME:-}" ]; then
            error_exit "No database associated with site: $identifier"
        fi

        db_type="$SITE_DB_TYPE"
        db_name="$DB_NAME"
        db_user="$DB_USER"
        db_password="$DB_PASSWORD"
    else
        # Assume it's a database name
        # Try to determine the database type
        if mysql -u root -e "SHOW DATABASES LIKE '$identifier'" 2>/dev/null | grep -q "$identifier"; then
            db_type="mysql"
            db_name="$identifier"
        elif sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$identifier"; then
            db_type="postgres"
            db_name="$identifier"
        else
            error_exit "Database not found: $identifier"
        fi
    fi

    # Get backup file
    local backup_file=$(get_opt "file" "")
    if [ -z "$backup_file" ]; then
        read -p "Backup file path: " backup_file
    fi

    if [ ! -f "$backup_file" ]; then
        error_exit "Backup file not found: $backup_file"
    fi

    # Check if it's compressed
    local is_compressed=false
    if [[ "$backup_file" == *.gz ]]; then
        is_compressed=true
    fi

    # Log the action
    log "INFO" "Restoring database: $db_name of type: $db_type from file: $backup_file"

    # Confirm restoration
    read -p "This will overwrite the current database. Are you sure? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Operation cancelled"
        return 0
    fi

    # Execute restoration
    case "$db_type" in
        mysql)
            if [ "$is_compressed" = true ]; then
                if gunzip -c "$backup_file" | mysql -u root "$db_name"; then
                    success "MySQL database restored successfully from: $backup_file"
                else
                    error_exit "Failed to restore MySQL database: $db_name"
                fi
            else
                if mysql -u root "$db_name" < "$backup_file"; then
                    success "MySQL database restored successfully from: $backup_file"
                else
                    error_exit "Failed to restore MySQL database: $db_name"
                fi
            fi
            ;;
        postgres)
            if [ "$is_compressed" = true ]; then
                if gunzip -c "$backup_file" | sudo -u postgres psql "$db_name"; then
                    success "PostgreSQL database restored successfully from: $backup_file"
                else
                    error_exit "Failed to restore PostgreSQL database: $db_name"
                fi
            else
                if sudo -u postgres psql "$db_name" < "$backup_file"; then
                    success "PostgreSQL database restored successfully from: $backup_file"
                else
                    error_exit "Failed to restore PostgreSQL database: $db_name"
                fi
            fi
            ;;
    esac
}

# List all databases
db_list() {
    log "INFO" "Listing all databases"

    echo -e "${BLUE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│                    MySQL Databases                          │${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    if command_exists mysql; then
        mysql -u root -e "SHOW DATABASES" | grep -v "Database\|information_schema\|performance_schema\|mysql\|sys"
    else
        echo -e "${YELLOW}MySQL is not installed${NC}"
    fi

    echo ""
    echo -e "${BLUE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│                  PostgreSQL Databases                       │${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    if command_exists psql; then
        sudo -u postgres psql -c "\l" | grep -v "template0\|template1\|postgres"
    else
        echo -e "${YELLOW}PostgreSQL is not installed${NC}"
    fi
}

# ===== SYSTEM MANAGEMENT FUNCTIONS =====

# System management
system() {
    log "INFO" "Starting system management process"

    # Parse arguments
    parse_args "$@"

    # Get subcommand
    local subcommand="${ARGS[1]:-}"
    if [ -z "$subcommand" ]; then
        show_system_help
        return 0
    fi

    case "$subcommand" in
        status)
            system_status
            ;;
        update)
            system_update
            ;;
        upgrade)
            system_upgrade
            ;;
        health)
            system_health
            ;;
        --help)
            show_system_help
            ;;
        *)
            error_exit "Unknown system subcommand: $subcommand"
            ;;
    esac
}

# Show system status
system_status() {
    log "INFO" "Showing system status"

    echo -e "${BLUE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│                     System Status                           │${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # System information
    echo -e "${GREEN}Hostname:${NC} $(hostname)"
    echo -e "${GREEN}OS:${NC} $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')"
    echo -e "${GREEN}Kernel:${NC} $(uname -r)"
    echo -e "${GREEN}Uptime:${NC} $(uptime -p)"
    echo -e "${GREEN}Load Average:${NC} $(uptime | awk -F'load average:' '{print $2}')"

    # CPU information
    echo ""
    echo -e "${BLUE}CPU Information:${NC}"
    echo -e "${GREEN}CPU Usage:${NC} $(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')%"
    echo -e "${GREEN}CPU Cores:${NC} $(nproc)"

    # Memory information
    echo ""
    echo -e "${BLUE}Memory Information:${NC}"
    echo -e "${GREEN}Total Memory:${NC} $(free -h | awk '/^Mem:/ {print $2}')"
    echo -e "${GREEN}Used Memory:${NC} $(free -h | awk '/^Mem:/ {print $3}')"
    echo -e "${GREEN}Free Memory:${NC} $(free -h | awk '/^Mem:/ {print $4}')"

    # Disk information
    echo ""
    echo -e "${BLUE}Disk Information:${NC}"
    df -h | grep -v "tmpfs\|udev"

    # Service status
    echo ""
    echo -e "${BLUE}Service Status:${NC}"

    # Check Nginx
    if systemctl is-active --quiet nginx; then
        echo -e "${GREEN}Nginx:${NC} Running"
    else
        echo -e "${RED}Nginx:${NC} Not running"
    fi

    # Check PHP-FPM
    for version in 7.4 8.0 8.1 8.2 8.3; do
        if systemctl is-active --quiet php$version-fpm 2>/dev/null; then
            echo -e "${GREEN}PHP $version:${NC} Running"
        fi
    done

    # Check MySQL
    if systemctl is-active --quiet mysql 2>/dev/null; then
        echo -e "${GREEN}MySQL:${NC} Running"
    fi

    # Check PostgreSQL
    if systemctl is-active --quiet postgresql 2>/dev/null; then
        echo -e "${GREEN}PostgreSQL:${NC} Running"
    fi

    # Check PM2
    if command_exists pm2 && pm2 ping >/dev/null 2>&1; then
        echo -e "${GREEN}PM2:${NC} Running"
        echo ""
        echo -e "${BLUE}PM2 Processes:${NC}"
        pm2 list
    fi
}

# Update system packages
system_update() {
    log "INFO" "Updating system packages"

    echo -e "${BLUE}Updating system packages...${NC}"

    # Update package lists
    apt-get update

    # Upgrade packages
    apt-get upgrade -y

    success "System packages updated successfully"
}

# Upgrade VPS Manager
system_upgrade() {
    log "INFO" "Upgrading VPS Manager"

    echo -e "${BLUE}Upgrading VPS Manager...${NC}"

    # Check if git is installed
    if ! command_exists git; then
        apt-get update
        apt-get install -y git
    fi

    # Create temporary directory
    local temp_dir=$(mktemp -d)

    # Clone the repository
    git clone https://github.com/user/vps-manager.git "$temp_dir"

    # Run the installation script
    cd "$temp_dir"
    bash install.sh

    # Clean up
    rm -rf "$temp_dir"

    success "VPS Manager upgraded successfully"
}

# Run health checks
system_health() {
    log "INFO" "Running health checks"

    echo -e "${BLUE}Running health checks...${NC}"

    # Check disk space
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
    if [ "$disk_usage" -gt 90 ]; then
        echo -e "${RED}WARNING: Disk usage is high (${disk_usage}%)${NC}"
    else
        echo -e "${GREEN}Disk usage is normal (${disk_usage}%)${NC}"
    fi

    # Check memory usage
    local mem_usage=$(free | awk '/^Mem:/ {printf("%.2f", $3/$2 * 100)}')
    if (( $(echo "$mem_usage > 90" | bc -l) )); then
        echo -e "${RED}WARNING: Memory usage is high (${mem_usage}%)${NC}"
    else
        echo -e "${GREEN}Memory usage is normal (${mem_usage}%)${NC}"
    fi

    # Check load average
    local load=$(uptime | awk -F'load average:' '{print $2}' | awk -F, '{print $1}' | tr -d ' ')
    local cores=$(nproc)
    if (( $(echo "$load > $cores" | bc -l) )); then
        echo -e "${RED}WARNING: Load average is high (${load})${NC}"
    else
        echo -e "${GREEN}Load average is normal (${load})${NC}"
    fi

    # Check for failed services
    echo ""
    echo -e "${BLUE}Checking for failed services...${NC}"
    systemctl --failed

    # Check for security updates
    echo ""
    echo -e "${BLUE}Checking for security updates...${NC}"
    apt-get update
    apt-get -s upgrade | grep -i security

    # Check Nginx configuration
    echo ""
    echo -e "${BLUE}Checking Nginx configuration...${NC}"
    if nginx -t; then
        echo -e "${GREEN}Nginx configuration is valid${NC}"
    else
        echo -e "${RED}WARNING: Nginx configuration is invalid${NC}"
    fi

    # Check SSL certificates expiration
    echo ""
    echo -e "${BLUE}Checking SSL certificates expiration...${NC}"
    for domain in $(ls $CONFIG_DIR/configs/*.json 2>/dev/null | xargs -n1 basename | sed 's/\.json$//'); do
        if [ -f "/etc/nginx/sites-available/$domain" ] && grep -q "ssl_certificate" "/etc/nginx/sites-available/$domain"; then
            local cert_path=$(grep "ssl_certificate " "/etc/nginx/sites-available/$domain" | awk '{print $2}' | sed 's/;$//')
            local expiry=$(openssl x509 -enddate -noout -in "$cert_path" | cut -d= -f2)
            local expiry_date=$(date -d "$expiry" +%s)
            local current_date=$(date +%s)
            local days_left=$(( ($expiry_date - $current_date) / 86400 ))

            if [ $days_left -lt 7 ]; then
                echo -e "${RED}WARNING: Certificate for $domain will expire in $days_left days${NC}"
            elif [ $days_left -lt 30 ]; then
                echo -e "${YELLOW}NOTICE: Certificate for $domain will expire in $days_left days${NC}"
            else
                echo -e "${GREEN}Certificate for $domain is valid for $days_left days${NC}"
            fi
        fi
    done

    success "Health checks completed"
}

# ===== LOGS MANAGEMENT FUNCTIONS =====

# Logs management
logs() {
    log "INFO" "Starting logs management process"

    # Parse arguments
    parse_args "$@"

    # Get subcommand
    local subcommand="${ARGS[1]:-}"
    if [ -z "$subcommand" ]; then
        show_logs_help
        return 0
    fi

    case "$subcommand" in
        tail)
            logs_tail "${ARGS[@]:1}"
            ;;
        view)
            logs_view "${ARGS[@]:1}"
            ;;
        clear)
            logs_clear "${ARGS[@]:1}"
            ;;
        --help)
            show_logs_help
            ;;
        *)
            error_exit "Unknown logs subcommand: $subcommand"
            ;;
    esac
}

# Tail logs
logs_tail() {
    # Parse arguments
    parse_args "$@"

    # Get domain (either from first argument or prompt)
    local domain="${ARGS[1]:-}"
    if [ -z "$domain" ]; then
        while true; do
            read -p "Domain name: " domain
            if validate_domain "$domain"; then
                break
            else
                echo -e "${RED}Invalid domain format${NC}"
            fi
        done
    else
        if ! validate_domain "$domain"; then
            error_exit "Invalid domain format: $domain"
        fi
    fi

    # Check if site exists
    if ! site_exists "$domain"; then
        error_exit "Site does not exist: $domain"
    fi

    # Get log type
    local log_type=$(get_opt "type" "access")

    # Get number of lines
    local lines=$(get_opt "lines" "100")

    # Log the action
    log "INFO" "Tailing logs for site: $domain, type: $log_type, lines: $lines"

    # Determine log file path
    local log_file=""
    case "$log_type" in
        access)
            log_file="/var/log/sites/$domain/access.log"
            ;;
        error)
            log_file="/var/log/sites/$domain/error.log"
            ;;
        php)
            log_file="/var/log/sites/$domain/php-error.log"
            ;;
        *)
            error_exit "Invalid log type: $log_type"
            ;;
    esac

    # Check if log file exists
    if [ ! -f "$log_file" ]; then
        error_exit "Log file not found: $log_file"
    fi

    # Tail the log file
    tail -n "$lines" -f "$log_file"
}

# View logs
logs_view() {
    # Parse arguments
    parse_args "$@"

    # Get domain (either from first argument or prompt)
    local domain="${ARGS[1]:-}"
    if [ -z "$domain" ]; then
        while true; do
            read -p "Domain name: " domain
            if validate_domain "$domain"; then
                break
            else
                echo -e "${RED}Invalid domain format${NC}"
            fi
        done
    else
        if ! validate_domain "$domain"; then
            error_exit "Invalid domain format: $domain"
        fi
    fi

    # Check if site exists
    if ! site_exists "$domain"; then
        error_exit "Site does not exist: $domain"
    fi

    # Get log type
    local log_type=$(get_opt "type" "access")

    # Log the action
    log "INFO" "Viewing logs for site: $domain, type: $log_type"

    # Determine log file path
    local log_file=""
    case "$log_type" in
        access)
            log_file="/var/log/sites/$domain/access.log"
            ;;
        error)
            log_file="/var/log/sites/$domain/error.log"
            ;;
        php)
            log_file="/var/log/sites/$domain/php-error.log"
            ;;
        *)
            error_exit "Invalid log type: $log_type"
            ;;
    esac

    # Check if log file exists
    if [ ! -f "$log_file" ]; then
        error_exit "Log file not found: $log_file"
    fi

    # View the log file
    less "$log_file"
}

# Clear logs
logs_clear() {
    # Parse arguments
    parse_args "$@"

    # Get domain (either from first argument or prompt)
    local domain="${ARGS[1]:-}"
    if [ -z "$domain" ]; then
        while true; do
            read -p "Domain name: " domain
            if validate_domain "$domain"; then
                break
            else
                echo -e "${RED}Invalid domain format${NC}"
            fi
        done
    else
        if ! validate_domain "$domain"; then
            error_exit "Invalid domain format: $domain"
        fi
    fi

    # Check if site exists
    if ! site_exists "$domain"; then
        error_exit "Site does not exist: $domain"
    fi

    # Get log type
    local log_type=$(get_opt "type" "all")

    # Log the action
    log "INFO" "Clearing logs for site: $domain, type: $log_type"

    # Confirm clearing
    read -p "Are you sure you want to clear logs for $domain? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Operation cancelled"
        return 0
    fi

    # Clear logs
    case "$log_type" in
        access)
            > "/var/log/sites/$domain/access.log"
            success "Access logs cleared for: $domain"
            ;;
        error)
            > "/var/log/sites/$domain/error.log"
            success "Error logs cleared for: $domain"
            ;;
        php)
            > "/var/log/sites/$domain/php-error.log"
            success "PHP error logs cleared for: $domain"
            ;;
        all)
            > "/var/log/sites/$domain/access.log"
            > "/var/log/sites/$domain/error.log"
            > "/var/log/sites/$domain/php-error.log"
            success "All logs cleared for: $domain"
            ;;
        *)
            error_exit "Invalid log type: $log_type"
            ;;
    esac
}

# ===== MAIN FUNCTION =====

# Main execution
main() {
    # Parse arguments
    parse_args "$@"

    # Get command
    local command="${ARGS[0]:-}"

    # Execute command
    case "$command" in
        site)
            # Get subcommand
            local subcommand="${ARGS[1]:-}"
            if [ -z "$subcommand" ]; then
                show_site_help
                return 0
            fi

            case "$subcommand" in
                create)
                    site_create "${ARGS[@]:1}"
                    ;;
                remove)
                    site_remove "${ARGS[@]:1}"
                    ;;
                list)
                    site_list
                    ;;
                info)
                    site_info "${ARGS[@]:1}"
                    ;;
                backup)
                    site_backup "${ARGS[@]:1}"
                    ;;
                --help)
                    show_site_help
                    ;;
                *)
                    error_exit "Unknown site subcommand: $subcommand"
                    ;;
            esac
            ;;
        deploy)
            deploy "$@"
            ;;
        ssl)
            ssl "$@"
            ;;
        db)
            db "$@"
            ;;
        system)
            system "$@"
            ;;
        logs)
            logs "$@"
            ;;
        # Legacy command support
        create-site)
            warn "Command 'create-site' is deprecated, use 'site create' instead"
            site_create "${ARGS[@]:1}"
            ;;
        remove-site)
            warn "Command 'remove-site' is deprecated, use 'site remove' instead"
            site_remove "${ARGS[@]:1}"
            ;;
        list-sites)
            warn "Command 'list-sites' is deprecated, use 'site list' instead"
            site_list
            ;;
        backup-site)
            warn "Command 'backup-site' is deprecated, use 'site backup' instead"
            site_backup "${ARGS[@]:1}"
            ;;
        site-info)
            warn "Command 'site-info' is deprecated, use 'site info' instead"
            site_info "${ARGS[@]:1}"
            ;;
        ssl-setup)
            warn "Command 'ssl-setup' is deprecated, use 'ssl enable' instead"
            ssl_enable "${ARGS[@]:1}"
            ;;
        update-perms)
            warn "Command 'update-perms' is deprecated, use 'system update-permissions' instead"
            $SCRIPT_DIR/utils/update-permissions.sh "${ARGS[@]:1}"
            ;;
        --help|-h|help)
            show_main_help
            ;;
        --version|-v|version)
            echo "VPS Manager v$VPS_MANAGER_VERSION"
            ;;
        *)
            show_main_help
            ;;
    esac
}

# Execute main function
main "$@"
