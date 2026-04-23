#!/bin/bash

# ArcPanel Installer Script
# Production-grade installer for ArcPanel on Ubuntu 22.04
# Version: 1.0.0

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
DOMAIN=""
EMAIL=""
DB_NAME=""
DB_USER=""
DB_PASS=""
INSTALL_DIR="/var/www/arcpanel"

# Logging function
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
}

# Update system packages
update_system() {
    log "Updating system packages..."
    apt update && apt upgrade -y
}

# Install system dependencies
install_dependencies() {
    log "Installing system dependencies..."

    # Add PHP repository
    apt install -y software-properties-common
    add-apt-repository ppa:ondrej/php -y
    apt update

    # Install packages
    apt install -y \
        nginx \
        mysql-server \
        redis-server \
        php8.2-cli \
        php8.2-fpm \
        php8.2-mysql \
        php8.2-xml \
        php8.2-mbstring \
        php8.2-curl \
        php8.2-zip \
        php8.2-bcmath \
        php8.2-gd \
        php8.2-intl \
        php8.2-redis \
        curl \
        git \
        unzip \
        supervisor

    # Install Node.js 18
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt install -y nodejs

    # Install Composer
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

    # Install Certbot
    apt install -y certbot python3-certbot-nginx

    log "Dependencies installed successfully"
}

# Setup MySQL database
setup_database() {
    log "Setting up MySQL database..."

    # Start MySQL if not running
    systemctl start mysql
    systemctl enable mysql

    # Create database and user
    mysql -u root -e "CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    mysql -u root -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
    mysql -u root -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
    mysql -u root -e "FLUSH PRIVILEGES;"

    log "Database setup completed"
}

# Install ArcPanel
install_arcpanel() {
    log "Installing ArcPanel..."

    # Create install directory
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"

    # Clone repository (assuming it's on GitHub, replace with actual repo)
    if [[ ! -d ".git" ]]; then
        git clone https://github.com/NotRayy01/arcpanel.git .
        # Note: In real scenario, this would be the ArcPanel repo
    fi

    # Copy environment file
    if [[ ! -f ".env" ]]; then
        cp .env.example .env
    fi

    # Configure .env
    sed -i "s|APP_URL=.*|APP_URL=https://$DOMAIN|" .env
    sed -i "s|DB_DATABASE=.*|DB_DATABASE=$DB_NAME|" .env
    sed -i "s|DB_USERNAME=.*|DB_USERNAME=$DB_USER|" .env
    sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASS|" .env
    sed -i "s|CACHE_DRIVER=.*|CACHE_DRIVER=redis|" .env
    sed -i "s|QUEUE_CONNECTION=.*|QUEUE_CONNECTION=redis|" .env
    sed -i "s|SESSION_DRIVER=.*|SESSION_DRIVER=redis|" .env

    # Install PHP dependencies
    composer install --no-dev --optimize-autoloader

    # Install Node dependencies and build
    npm install
    npm run build

    # Generate application key
    php artisan key:generate

    # Run migrations and seed
    php artisan migrate --seed

    # Create storage link
    php artisan storage:link

    log "ArcPanel installed successfully"
}

# Set permissions
set_permissions() {
    log "Setting permissions..."

    chown -R www-data:www-data "$INSTALL_DIR"
    chmod -R 755 "$INSTALL_DIR/storage"
    chmod -R 755 "$INSTALL_DIR/bootstrap/cache"

    log "Permissions set"
}

# Configure Nginx
configure_nginx() {
    log "Configuring Nginx..."

    cat > /etc/nginx/sites-available/arcpanel << EOF
server {
    listen 80;
    server_name $DOMAIN;
    root $INSTALL_DIR/public;

    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

    # Enable site
    ln -sf /etc/nginx/sites-available/arcpanel /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default

    # Test and restart nginx
    nginx -t
    systemctl restart nginx
    systemctl enable nginx

    log "Nginx configured"
}

# Setup SSL
setup_ssl() {
    log "Setting up SSL certificate..."

    # Request certificate
    certbot --nginx -d "$DOMAIN" --email "$EMAIL" --agree-tos --non-interactive

    # Add HTTPS redirect
    cat >> /etc/nginx/sites-available/arcpanel << EOF

server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}
EOF

    systemctl restart nginx

    log "SSL setup completed"
}

# Setup queue worker
setup_queue_worker() {
    log "Setting up queue worker..."

    cat > /etc/supervisor/conf.d/arcpanel-worker.conf << EOF
[program:arcpanel-worker]
process_name=%(program_name)s_%(process_num)02d
command=php $INSTALL_DIR/artisan queue:work --sleep=3 --tries=3
directory=$INSTALL_DIR
autostart=true
autorestart=true
user=www-data
numprocs=1
redirect_stderr=true
stdout_logfile=$INSTALL_DIR/storage/logs/worker.log
EOF

    supervisorctl reread
    supervisorctl update
    supervisorctl start arcpanel-worker

    log "Queue worker setup completed"
}

# Get user input
get_user_input() {
    log "Welcome to ArcPanel Installer"

    read -p "Enter domain name (e.g. panel.example.com): " DOMAIN
    if [[ -z "$DOMAIN" ]]; then
        error "Domain is required"
        exit 1
    fi

    read -p "Enter email for SSL certificate: " EMAIL
    if [[ -z "$EMAIL" ]]; then
        error "Email is required"
        exit 1
    fi

    read -p "Enter database name [arcpanel]: " DB_NAME
    DB_NAME=${DB_NAME:-arcpanel}

    read -p "Enter database user [arcpanel]: " DB_USER
    DB_USER=${DB_USER:-arcpanel}

    read -s -p "Enter database password: " DB_PASS
    echo
    if [[ -z "$DB_PASS" ]]; then
        error "Database password is required"
        exit 1
    fi

    read -p "Enter install directory [/var/www/arcpanel]: " INSTALL_DIR
    INSTALL_DIR=${INSTALL_DIR:-/var/www/arcpanel}
}

# Main installation function
main() {
    check_root
    get_user_input
    update_system
    install_dependencies
    setup_database
    install_arcpanel
    set_permissions
    configure_nginx
    setup_ssl
    setup_queue_worker

    log "ArcPanel installation completed successfully!"
    echo
    echo -e "${BLUE}Panel URL:${NC} https://$DOMAIN"
    echo -e "${BLUE}Admin Login:${NC} Use the credentials created during seeding"
    echo
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Visit https://$DOMAIN to access your panel"
    echo "2. Complete the initial setup wizard"
    echo "3. Configure your first node and eggs"
    echo
    echo -e "${GREEN}Installation complete!${NC}"
}

# Run main function
main "$@"