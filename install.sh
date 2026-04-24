#!/bin/bash

# ArcPanel Installer Script
# Production-grade installer for ArcPanel - Multi-OS Support
# Version: 2.0.0
# Supports: Ubuntu, Debian, CentOS, RHEL, Alpine, Fedora, Arch

set -e

# ============================================================================
# COLOR CODES & SYMBOLS
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m'

# Symbols and Emojis
CHECKMARK="✓"
CROSS="✗"
ARROW="➜"
INFO="ℹ"
WARNING="⚠"
FIRE="🔥"
ROCKET="🚀"
BOX="█"
CIRCLE="●"
STAR="★"
HEART="❤"
GEAR="⚙"
DATABASE="🗄"
LOCK="🔒"
HOURGLASS="⏳"

# Global variables
DOMAIN=""
EMAIL=""
DB_NAME=""
DB_USER=""
DB_PASS=""
INSTALL_DIR="/var/www/arcpanel"
OS_TYPE=""
PKG_MANAGER=""
PHP_VERSION="8.2"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Animated loading spinner
spinner() {
    local pid=$1
    local delay=0.1
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local spin_count=0
    
    while kill -0 $pid 2>/dev/null; do
        printf "\r${CYAN}${frames[$((spin_count % ${#frames[@]}))]}${NC} "
        sleep $delay
        ((spin_count++))
    done
    
    # Wait a bit more to ensure the process has actually finished
    sleep 0.5
    
    # Clear the spinner
    printf "\r"
}

# Progress bar
progress_bar() {
    local current=$1
    local total=$2
    local width=30
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    
    printf "${CYAN}["
    printf '%*s' "$filled" | tr ' ' "${BOX}"
    printf '%*s' $((width - filled)) | tr ' ' '-'
    printf "]${NC} ${percentage}%%\r"
}

# Animated text
animate_text() {
    local text="$1"
    local delay=${2:-0.05}
    for ((i = 0; i < ${#text}; i++)); do
        echo -n "${text:$i:1}"
        sleep $delay
    done
    echo
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}${CROSS}${NC} This script must be run as root"
        echo -e "${YELLOW}${INFO}${NC} Try: ${CYAN}sudo ./install.sh${NC}"
        exit 1
    fi
}

# Detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_TYPE="$ID"
        case "$OS_TYPE" in
            ubuntu|debian)
                PKG_MANAGER="apt"
                ;;
            centos|rhel|fedora)
                if command -v dnf &> /dev/null; then
                    PKG_MANAGER="dnf"
                else
                    PKG_MANAGER="yum"
                fi
                ;;
            alpine)
                PKG_MANAGER="apk"
                ;;
            arch|manjaro)
                PKG_MANAGER="pacman"
                ;;
            *)
                echo -e "${RED}${CROSS}${NC} Unsupported OS: $OS_TYPE"
                exit 1
                ;;
        esac
    else
        echo -e "${RED}${CROSS}${NC} Cannot detect OS"
        exit 1
    fi
}

# Logging functions with emojis
log() {
    echo -e "${GREEN}${CHECKMARK}${NC} ${GREEN}$1${NC}"
}

success() {
    echo -e "${GREEN}${STAR}${NC} ${GREEN}$1${NC}"
}

warn() {
    echo -e "${YELLOW}${WARNING}${NC} ${YELLOW}$1${NC}"
}

error() {
    echo -e "${RED}${CROSS}${NC} ${RED}$1${NC}"
}

info() {
    echo -e "${CYAN}${INFO}${NC} ${CYAN}$1${NC}"
}

# Print header
print_header() {
    clear
    echo -e "${MAGENTA}"
    cat << "EOF"
    ╔══════════════════════════════════════════════════════════╗
    ║                                                          ║
    ║   🚀  ArcPanel Installer - Multi-OS Edition v2.0  🚀    ║
    ║                                                          ║
    ║              Production-Grade Installer                 ║
    ║                                                          ║
    ╚══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Print section
print_section() {
    echo -e "\n${BLUE}${ARROW} ${BLUE}$1${NC}"
    echo -e "${GRAY}───────────────────────────────────────────────────────${NC}"
}

# ============================================================================
# PACKAGE MANAGER HANDLERS
# ============================================================================# ============================================================================
# PACKAGE MANAGER HANDLERS
# ============================================================================

update_system() {
    print_section "${HOURGLASS} Updating System Packages"
    
    case "$PKG_MANAGER" in
        apt)
            apt update && apt upgrade -y >/dev/null 2>&1 &
            local pid=$!
            spinner $pid
            wait $pid
            ;;
        dnf)
            dnf upgrade -y >/dev/null 2>&1 &
            local pid=$!
            spinner $pid
            wait $pid
            ;;
        yum)
            yum update -y >/dev/null 2>&1 &
            local pid=$!
            spinner $pid
            wait $pid
            ;;
        apk)
            apk update && apk upgrade >/dev/null 2>&1 &
            local pid=$!
            spinner $pid
            wait $pid
            ;;
        pacman)
            pacman -Syu --noconfirm >/dev/null 2>&1 &
            local pid=$!
            spinner $pid
            wait $pid
            ;;
    esac
    success "System packages updated"
}

install_dependencies() {
    print_section "${GEAR} Installing Dependencies"
    
    local packages=()
    
    case "$PKG_MANAGER" in
        apt)
            # Add PHP PPA
            info "Adding PHP PPA..."
            add-apt-repository ppa:ondrej/php -y >/dev/null 2>&1 || warn "PHP PPA may already be added"
            
            if [[ -n "$PHP_VERSION" ]]; then
                packages=(
                    "nginx" "mysql-server" "redis-server"
                    "php${PHP_VERSION}-cli" "php${PHP_VERSION}-fpm" "php${PHP_VERSION}-mysql"
                    "php${PHP_VERSION}-xml" "php${PHP_VERSION}-mbstring" "php${PHP_VERSION}-curl"
                    "php${PHP_VERSION}-zip" "php${PHP_VERSION}-bcmath" "php${PHP_VERSION}-gd"
                    "php${PHP_VERSION}-intl" "php${PHP_VERSION}-redis"
                    "curl" "git" "unzip" "supervisor" "software-properties-common"
                )
            else
                packages=(
                    "nginx" "mysql-server" "redis-server"
                    "php-cli" "php-fpm" "php-mysql"
                    "php-xml" "php-mbstring" "php-curl"
                    "php-zip" "php-bcmath" "php-gd"
                    "php-intl" "php-redis"
                    "curl" "git" "unzip" "supervisor" "software-properties-common"
                )
            fi
            
            info "Updating package lists..."
            if ! apt update >/dev/null 2>&1; then
                error "Failed to update package lists"
                exit 1
            fi
            ;;
        dnf)
            packages=(
                "nginx" "mysql-server" "redis"
                "php-cli" "php-fpm" "php-mysql" "php-xml"
                "php-mbstring" "php-curl" "php-zip" "php-bcmath"
                "php-gd" "php-intl" "php-pecl-redis"
                "curl" "git" "unzip" "supervisor"
            )
            ;;
        yum)
            packages=(
                "epel-release" "nginx" "mysql-server" "redis"
                "php-cli" "php-fpm" "php-mysql" "php-xml"
                "php-mbstring" "php-curl" "php-zip" "php-bcmath"
                "php-gd" "php-intl" "php-pecl-redis"
                "curl" "git" "unzip" "supervisor"
            )
            ;;
        apk)
            packages=(
                "nginx" "mysql" "redis"
                "php82" "php82-cli" "php82-fpm" "php82-pdo_mysql"
                "php82-xml" "php82-mbstring" "php82-curl"
                "php82-zip" "php82-bcmath" "php82-gd" "php82-intl"
                "php82-pecl-redis"
                "curl" "git" "unzip" "supervisor"
            )
            ;;
        pacman)
            packages=(
                "nginx" "mysql" "redis"
                "php" "php-fpm"
                "curl" "git" "unzip" "supervisor"
            )
            ;;
    esac
    
    info "Installing ${#packages[@]} packages..."
    echo -e "${CYAN}This may take a few minutes...${NC}"
    
    case "$PKG_MANAGER" in
        apt)
            if ! apt install -y "${packages[@]}"; then
                error "Failed to install packages with apt"
                exit 1
            fi
            ;;
        dnf)
            if ! dnf install -y "${packages[@]}"; then
                error "Failed to install packages with dnf"
                exit 1
            fi
            ;;
        yum)
            if ! yum install -y "${packages[@]}"; then
                error "Failed to install packages with yum"
                exit 1
            fi
            ;;
        apk)
            if ! apk add "${packages[@]}"; then
                error "Failed to install packages with apk"
                exit 1
            fi
            ;;
        pacman)
            if ! pacman -S --noconfirm "${packages[@]}"; then
                error "Failed to install packages with pacman"
                exit 1
            fi
            ;;
    esac
    
    success "Dependencies installed"
}

install_nodejs_composer() {
    print_section "${ROCKET} Installing Node.js and Composer"
    
    # Node.js
    info "Installing Node.js 22..."
    case "$PKG_MANAGER" in
        apt)
            curl -fsSL https://deb.nodesource.com/setup_22.x | bash - >/dev/null 2>&1
            apt install -y nodejs >/dev/null 2>&1 &
            ;;
        dnf|yum)
            dnf install -y nodejs npm >/dev/null 2>&1 &
            ;;
        apk)
            apk add nodejs npm >/dev/null 2>&1 &
            ;;
        pacman)
            pacman -S --noconfirm nodejs npm >/dev/null 2>&1 &
            ;;
    esac
    
    local pid=$!
    spinner $pid
    wait $pid
    success "Node.js installed: $(node -v)"
    
    # Composer
    info "Installing Composer..."
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer >/dev/null 2>&1 &
    pid=$!
    spinner $pid
    wait $pid
    success "Composer installed: $(composer --version)"
    
    # Certbot
    info "Installing Certbot..."
    case "$PKG_MANAGER" in
        apt)
            apt install -y certbot python3-certbot-nginx >/dev/null 2>&1 &
            ;;
        dnf)
            dnf install -y certbot python3-certbot-nginx >/dev/null 2>&1 &
            ;;
        yum)
            yum install -y certbot python3-certbot-nginx >/dev/null 2>&1 &
            ;;
        apk)
            apk add certbot >/dev/null 2>&1 &
            ;;
        pacman)
            pacman -S --noconfirm certbot certbot-nginx >/dev/null 2>&1 &
            ;;
    esac
    
    pid=$!
    spinner $pid
    wait $pid
    success "Certbot installed"
}

# ============================================================================
# DATABASE SETUP
# ============================================================================

# ============================================================================
# DATABASE SETUP
# ============================================================================

setup_database() {
    print_section "${DATABASE} Setting Up Database"
    
    # Start services
    info "Starting database server..."
    case "$PKG_MANAGER" in
        apk)
            rc-service mariadb start >/dev/null 2>&1 &
            ;;
        pacman)
            systemctl start mariadb >/dev/null 2>&1 &
            ;;
        *)
            systemctl start mysql >/dev/null 2>&1 &
            ;;
    esac
    
    local pid=$!
    spinner $pid
    wait $pid
    success "Database server started"
    
    info "Enabling database at startup..."
    case "$PKG_MANAGER" in
        apk)
            rc-update add mariadb >/dev/null 2>&1
            ;;
        *)
            systemctl enable mysql >/dev/null 2>&1 || systemctl enable mariadb >/dev/null 2>&1
            ;;
    esac
    
    # Create database and user
    info "Creating database and user..."
    mysql -u root -e "CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" >/dev/null 2>&1 &
    pid=$!
    spinner $pid
    wait $pid
    
    info "Setting up database user..."
    mysql -u root -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';" >/dev/null 2>&1
    mysql -u root -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';" >/dev/null 2>&1
    mysql -u root -e "FLUSH PRIVILEGES;" >/dev/null 2>&1 &
    pid=$!
    spinner $pid
    wait $pid
    
    success "Database setup completed"
}

# ============================================================================
# ARCPANEL INSTALLATION
# ============================================================================

# Install ArcPanel
install_arcpanel() {
    print_section "${ROCKET} Installing ArcPanel"
    
    # Create and navigate to install directory
    info "Creating installation directory: $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # Clone repository
    if [[ ! -d ".git" ]]; then
        info "Cloning ArcPanel repository..."
        git clone https://github.com/NotRayy01/arcpanel.git . >/dev/null 2>&1 &
        local pid=$!
        spinner $pid
        wait $pid
        success "Repository cloned"
    else
        info "Repository already exists, skipping clone"
    fi
    
    # Copy environment file
    if [[ ! -f ".env" ]]; then
        info "Setting up environment file..."
        cp .env.example .env
        success "Environment file created"
    fi
    
    # Configure .env
    print_section "${LOCK} Configuring Environment"
    info "Setting APP_URL: https://$DOMAIN"
    sed -i "s|APP_URL=.*|APP_URL=https://$DOMAIN|" .env
    
    info "Setting database credentials..."
    sed -i "s|DB_DATABASE=.*|DB_DATABASE=$DB_NAME|" .env
    sed -i "s|DB_USERNAME=.*|DB_USERNAME=$DB_USER|" .env
    sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASS|" .env
    
    info "Setting cache drivers..."
    sed -i "s|CACHE_DRIVER=.*|CACHE_DRIVER=redis|" .env
    sed -i "s|QUEUE_CONNECTION=.*|QUEUE_CONNECTION=redis|" .env
    sed -i "s|SESSION_DRIVER=.*|SESSION_DRIVER=redis|" .env
    
    success "Environment configured"
    
    # Install PHP dependencies
    print_section "${GEAR} Installing PHP Dependencies"
    info "Running composer install..."
    composer install --no-dev --optimize-autoloader >/dev/null 2>&1 &
    local pid=$!
    spinner $pid
    wait $pid
    success "PHP dependencies installed"
    
    # Install Node dependencies
    print_section "${ROCKET} Building Frontend"
    info "Installing Node dependencies..."
    npm install >/dev/null 2>&1 &
    pid=$!
    spinner $pid
    wait $pid
    
    info "Building assets..."
    npm run build >/dev/null 2>&1 &
    pid=$!
    spinner $pid
    wait $pid
    success "Frontend built"
    
    # Generate application key
    print_section "${STAR} Generating Application Key"
    php artisan key:generate >/dev/null 2>&1 &
    local pid=$!
    spinner $pid
    wait $pid
    success "Application key generated"
    
    # Run migrations
    print_section "${DATABASE} Running Database Migrations"
    info "Migrating database..."
    php artisan migrate --seed >/dev/null 2>&1 &
    pid=$!
    spinner $pid
    wait $pid
    success "Database migrated and seeded"
    
    # Create storage link
    info "Creating storage link..."
    php artisan storage:link >/dev/null 2>&1 &
    pid=$!
    spinner $pid
    wait $pid
    success "Storage link created"
}

# Set permissions
set_permissions() {
    print_section "${LOCK} Setting Permissions"
    
    info "Setting ownership to www-data..."
    chown -R www-data:www-data "$INSTALL_DIR" >/dev/null 2>&1 &
    local pid=$!
    spinner $pid
    wait $pid
    
    info "Setting storage permissions..."
    chmod -R 755 "$INSTALL_DIR/storage" >/dev/null 2>&1
    chmod -R 755 "$INSTALL_DIR/bootstrap/cache" >/dev/null 2>&1
    
    success "Permissions set correctly"
}

# Configure Nginx
configure_nginx() {
    print_section "${GEAR} Configuring Nginx"
    
    # Determine PHP socket path
    local php_socket
    if [[ -n "$PHP_VERSION" ]]; then
        php_socket="/var/run/php/php${PHP_VERSION}-fpm.sock"
    else
        # Try to find the PHP socket
        if [[ -S "/var/run/php/php8.2-fpm.sock" ]]; then
            php_socket="/var/run/php/php8.2-fpm.sock"
        elif [[ -S "/var/run/php/php8.1-fpm.sock" ]]; then
            php_socket="/var/run/php/php8.1-fpm.sock"
        elif [[ -S "/var/run/php/php8.0-fpm.sock" ]]; then
            php_socket="/var/run/php/php8.0-fpm.sock"
        elif [[ -S "/var/run/php/php-fpm.sock" ]]; then
            php_socket="/var/run/php/php-fpm.sock"
        else
            warn "Could not determine PHP socket path, using default"
            php_socket="/var/run/php/php-fpm.sock"
        fi
    fi
    
    info "Creating Nginx configuration..."
    cat > /etc/nginx/sites-available/arcpanel << EOF
server {
    listen 80;
    server_name $DOMAIN;
    root $INSTALL_DIR/public;

    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:$php_socket;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)\$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF
    
    success "Configuration created"
    
    info "Enabling Nginx site..."
    ln -sf /etc/nginx/sites-available/arcpanel /etc/nginx/sites-enabled/ >/dev/null 2>&1
    rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
    
    info "Testing Nginx configuration..."
    if ! nginx -t >/dev/null 2>&1; then
        error "Nginx configuration test failed"
        nginx -t  # Show the error
        exit 1
    fi
    
    info "Restarting Nginx..."
    if ! systemctl restart nginx >/dev/null 2>&1; then
        error "Failed to restart Nginx"
        exit 1
    fi
    
    systemctl enable nginx >/dev/null 2>&1
    
    success "Nginx configured and running"
}

# Setup SSL
setup_ssl() {
    print_section "${LOCK} Setting Up SSL Certificate"
    
    info "Requesting SSL certificate from Let's Encrypt..."
    certbot --nginx -d "$DOMAIN" --email "$EMAIL" --agree-tos --non-interactive >/dev/null 2>&1 &
    local pid=$!
    spinner $pid
    wait $pid
    
    success "SSL certificate installed"
    
    info "Adding HTTPS redirect..."
    cat >> /etc/nginx/sites-available/arcpanel << EOF

server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}
EOF

    systemctl restart nginx >/dev/null 2>&1
    
    success "HTTPS redirect configured"
}

# Setup queue worker
setup_queue_worker() {
    print_section "${GEAR} Setting Up Queue Worker"
    
    info "Creating Supervisor configuration..."
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
stopasgroup=true
stopwaitsecs=3600
EOF

    success "Supervisor configuration created"
    
    info "Reloading Supervisor..."
    supervisorctl reread >/dev/null 2>&1 &
    local pid=$!
    spinner $pid
    wait $pid
    
    supervisorctl update >/dev/null 2>&1 &
    pid=$!
    spinner $pid
    wait $pid
    
    info "Starting queue worker..."
    supervisorctl start arcpanel-worker >/dev/null 2>&1 &
    pid=$!
    spinner $pid
    wait $pid
    
    success "Queue worker started"
}

# Get user input
get_user_input() {
    print_header
    print_section "Configuration"
    
    read -p "${BLUE}${ARROW}${NC} Enter domain name (e.g panel.example.com): " DOMAIN
    if [[ -z "$DOMAIN" ]]; then
        error "Domain is required"
        exit 1
    fi
    log "Domain: $DOMAIN"

    read -p "${BLUE}${ARROW}${NC} Enter email for SSL certificate: " EMAIL
    if [[ -z "$EMAIL" ]]; then
        error "Email is required"
        exit 1
    fi
    log "Email: $EMAIL"

    read -p "${BLUE}${ARROW}${NC} Enter database name [${CYAN}arcpanel${NC}]: " DB_NAME
    DB_NAME=${DB_NAME:-arcpanel}
    log "Database name: $DB_NAME"

    read -p "${BLUE}${ARROW}${NC} Enter database user [${CYAN}arcpanel${NC}]: " DB_USER
    DB_USER=${DB_USER:-arcpanel}
    log "Database user: $DB_USER"

    read -sp "${BLUE}${ARROW}${NC} Enter database password: " DB_PASS
    echo
    if [[ -z "$DB_PASS" ]]; then
        error "Database password is required"
        exit 1
    fi
    success "Password set (hidden)"

    read -p "${BLUE}${ARROW}${NC} Enter install directory [${CYAN}/var/www/arcpanel${NC}]: " INSTALL_DIR
    INSTALL_DIR=${INSTALL_DIR:-/var/www/arcpanel}
    log "Install directory: $INSTALL_DIR"
}

# Main installation function
main() {
    print_header
    check_root
    detect_os
    
    info "Detected OS: ${CYAN}$OS_TYPE${NC}"
    info "Package Manager: ${CYAN}$PKG_MANAGER${NC}"
    
    echo
    get_user_input
    
    echo
    echo -e "${CYAN}${HOURGLASS} Installation will now begin...${NC}"
    sleep 2
    
    update_system
    install_dependencies
    install_nodejs_composer
    setup_database
    install_arcpanel
    set_permissions
    configure_nginx
    setup_ssl
    setup_queue_worker

    # Final output
    echo
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║${NC}                                                        ${MAGENTA}║${NC}"
    echo -e "${MAGENTA}║${NC}     ${GREEN}${STAR} Installation Completed Successfully! ${STAR}${NC}          ${MAGENTA}║${NC}"
    echo -e "${MAGENTA}║${NC}                                                        ${MAGENTA}║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════╝${NC}"
    
    echo
    echo -e "${BLUE}${INFO}${NC} ${CYAN}Panel Information:${NC}"
    echo -e "${BLUE}${ARROW}${NC} ${WHITE}URL:${NC} ${GREEN}https://$DOMAIN${NC}"
    echo -e "${BLUE}${ARROW}${NC} ${WHITE}Email:${NC} ${GREEN}$EMAIL${NC}"
    echo -e "${BLUE}${ARROW}${NC} ${WHITE}Directory:${NC} ${GREEN}$INSTALL_DIR${NC}"
    echo
    echo -e "${YELLOW}${WARNING}${NC} ${YELLOW}Next Steps:${NC}"
    echo -e "${CIRCLE} Visit ${GREEN}https://$DOMAIN${NC} to access your panel"
    echo -e "${CIRCLE} Complete the initial setup wizard"
    echo -e "${CIRCLE} Configure your first node and eggs"
    echo -e "${CIRCLE} Monitor queue worker: ${CYAN}supervisorctl status${NC}"
    echo
    echo -e "${FIRE} ${MAGENTA}Thank you for installing ArcPanel!${NC} ${FIRE}"
    echo
}

# Run main function
main "$@"
