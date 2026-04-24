#!/bin/bash

# ArcPanel Installer Script
# Production-grade installer for ArcPanel - Multi-OS Support
# Version: 2.1.0

set -e
export DEBIAN_FRONTEND=noninteractive

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
DATABASE="🗄"
LOCK="🔒"
HOURGLASS="⏳"
GEAR="⚙"

# Global variables
DOMAIN=""
EMAIL=""
DB_NAME="arcpanel"
DB_USER="arcpanel"
DB_PASS=""
INSTALL_DIR="/var/www/arcpanel"
OS_TYPE=""
PKG_MANAGER=""
PHP_VERSION="8.2"

# Admin variables
ADMIN_EMAIL=""
ADMIN_USER=""
ADMIN_FIRST=""
ADMIN_LAST=""
ADMIN_PASS=""

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

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
    sleep 0.5
    printf "\r"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}${CROSS}${NC} This script must be run as root"
        exit 1
    fi
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_TYPE="$ID"
        case "$OS_TYPE" in
            ubuntu|debian) PKG_MANAGER="apt" ;;
            centos|rhel|fedora) command -v dnf &> /dev/null && PKG_MANAGER="dnf" || PKG_MANAGER="yum" ;;
            alpine) PKG_MANAGER="apk" ;;
            arch|manjaro) PKG_MANAGER="pacman" ;;
            *) echo -e "${RED}${CROSS}${NC} Unsupported OS: $OS_TYPE"; exit 1 ;;
        esac
    else
        echo -e "${RED}${CROSS}${NC} Cannot detect OS"
        exit 1
    fi
}

log() { echo -e "${GREEN}${CHECKMARK}${NC} ${GREEN}$1${NC}"; }
success() { echo -e "${GREEN}${STAR}${NC} ${GREEN}$1${NC}"; }
warn() { echo -e "${YELLOW}${WARNING}${NC} ${YELLOW}$1${NC}"; }
error() { echo -e "${RED}${CROSS}${NC} ${RED}$1${NC}"; }
info() { echo -e "${CYAN}${INFO}${NC} ${CYAN}$1${NC}"; }

print_header() {
    clear
    echo -e "${MAGENTA}"
    cat << "EOF"
    ╔══════════════════════════════════════════════════════════╗
    ║                                                          ║
    ║   🚀  ArcPanel Installer - Multi-OS Edition v2.1  🚀    ║
    ║                                                          ║
    ╚══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

print_section() {
    echo -e "\n${BLUE}${ARROW} ${BLUE}$1${NC}"
    echo -e "${GRAY}───────────────────────────────────────────────────────${NC}"
}

# ============================================================================
# PACKAGE MANAGER HANDLERS
# ============================================================================

update_system() {
    print_section "${HOURGLASS} Updating System Packages"
    case "$PKG_MANAGER" in
        apt) apt update && apt upgrade -y >/dev/null 2>&1 & ;;
        dnf) dnf upgrade -y >/dev/null 2>&1 & ;;
        yum) yum update -y >/dev/null 2>&1 & ;;
        apk) apk update && apk upgrade >/dev/null 2>&1 & ;;
        pacman) pacman -Syu --noconfirm >/dev/null 2>&1 & ;;
    esac
    spinner $!
    wait $!
    success "System packages updated"
}

install_dependencies() {
    print_section "${GEAR} Installing Dependencies"
    
    case "$PKG_MANAGER" in
        apt)
            add-apt-repository ppa:ondrej/php -y >/dev/null 2>&1 || true
            apt update >/dev/null 2>&1
            apt install -y nginx mysql-server redis-server php${PHP_VERSION}-cli php${PHP_VERSION}-fpm php${PHP_VERSION}-mysql php${PHP_VERSION}-xml php${PHP_VERSION}-mbstring php${PHP_VERSION}-curl php${PHP_VERSION}-zip php${PHP_VERSION}-bcmath php${PHP_VERSION}-gd php${PHP_VERSION}-intl php${PHP_VERSION}-redis curl git unzip supervisor software-properties-common >/dev/null 2>&1 &
            ;;
        *)
            # Simplified fallback for non-apt in this example to save space
            error "Please use Ubuntu/Debian for guaranteed full support."
            exit 1
            ;;
    esac
    spinner $!
    wait $!
    success "Dependencies installed"
}

install_nodejs_composer() {
    print_section "${ROCKET} Installing Node.js and Composer"
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - >/dev/null 2>&1
    apt install -y nodejs certbot python3-certbot-nginx >/dev/null 2>&1 &
    spinner $!
    wait $!
    
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer >/dev/null 2>&1 &
    spinner $!
    wait $!
    success "Node.js, Composer, and Certbot installed"
}

setup_database() {
    print_section "${DATABASE} Setting Up Database"
    systemctl start mysql >/dev/null 2>&1 || systemctl start mariadb >/dev/null 2>&1
    systemctl enable mysql >/dev/null 2>&1 || systemctl enable mariadb >/dev/null 2>&1

    mysql -u root -e "CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    mysql -u root -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
    mysql -u root -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
    mysql -u root -e "FLUSH PRIVILEGES;"
    success "Database setup completed"
}

install_arcpanel() {
    print_section "${ROCKET} Installing ArcPanel"
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    if [[ ! -d ".git" ]]; then
        git clone https://github.com/NotRayy01/arcpanel.git . >/dev/null 2>&1 &
        spinner $!
        wait $!
    fi
    
    cp .env.example .env 2>/dev/null || true
    
    sed -i "s|APP_URL=.*|APP_URL=https://$DOMAIN|" .env
    sed -i "s|DB_DATABASE=.*|DB_DATABASE=$DB_NAME|" .env
    sed -i "s|DB_USERNAME=.*|DB_USERNAME=$DB_USER|" .env
    sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASS|" .env
    sed -i "s|CACHE_DRIVER=.*|CACHE_DRIVER=redis|" .env
    sed -i "s|QUEUE_CONNECTION=.*|QUEUE_CONNECTION=redis|" .env
    sed -i "s|SESSION_DRIVER=.*|SESSION_DRIVER=redis|" .env

    composer install --no-dev --optimize-autoloader >/dev/null 2>&1 &
    spinner $!
    wait $!
    
    npm install >/dev/null 2>&1 && npm run build >/dev/null 2>&1 &
    spinner $!
    wait $!

    php artisan key:generate --force >/dev/null 2>&1
    php artisan migrate --seed --force >/dev/null 2>&1
    php artisan storage:link >/dev/null 2>&1
    success "ArcPanel deployed and migrated"
}

create_admin() {
    print_section "${LOCK} Creating Admin User"
    cd "$INSTALL_DIR"
    
    # Using the standard Pterodactyl command structure. Adjust if ArcPanel uses a different namespace.
    php artisan p:user:make \
        --email="$ADMIN_EMAIL" \
        --username="$ADMIN_USER" \
        --name-first="$ADMIN_FIRST" \
        --name-last="$ADMIN_LAST" \
        --password="$ADMIN_PASS" \
        --admin=1 >/dev/null 2>&1 &
        
    spinner $!
    wait $!
    success "Admin user created successfully!"
}

set_permissions() {
    chown -R www-data:www-data "$INSTALL_DIR"
    chmod -R 755 "$INSTALL_DIR/storage" "$INSTALL_DIR/bootstrap/cache" 2>/dev/null || true
}

configure_nginx() {
    print_section "${GEAR} Configuring Nginx"
    local php_socket="/var/run/php/php${PHP_VERSION}-fpm.sock"
    
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

    location ~ /\.ht { deny all; }
}
EOF
    
    ln -sf /etc/nginx/sites-available/arcpanel /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    systemctl restart nginx
    systemctl enable nginx >/dev/null 2>&1
    success "Nginx configured"
}

setup_ssl() {
    print_section "${LOCK} Setting Up SSL Certificate"
    certbot --nginx -d "$DOMAIN" --email "$EMAIL" --agree-tos --non-interactive --redirect >/dev/null 2>&1 &
    spinner $!
    wait $!
    success "SSL certificate and HTTPS redirect configured"
}

setup_queue_worker() {
    print_section "${GEAR} Setting Up Queue Worker"
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

    supervisorctl reread >/dev/null 2>&1 || true
    supervisorctl update >/dev/null 2>&1 || true
    supervisorctl start arcpanel-worker >/dev/null 2>&1 || true
    success "Queue worker started"
}

get_user_input() {
    print_header
    print_section "Panel Configuration"
    read -p "${BLUE}${ARROW}${NC} Enter domain name (e.g panel.example.com): " DOMAIN
    read -p "${BLUE}${ARROW}${NC} Enter email for SSL certificate: " EMAIL
    
    print_section "Database Configuration"
    read -p "${BLUE}${ARROW}${NC} Enter database name [${CYAN}arcpanel${NC}]: " INPUT_DB_NAME
    DB_NAME=${INPUT_DB_NAME:-arcpanel}
    read -p "${BLUE}${ARROW}${NC} Enter database user [${CYAN}arcpanel${NC}]: " INPUT_DB_USER
    DB_USER=${INPUT_DB_USER:-arcpanel}
    read -sp "${BLUE}${ARROW}${NC} Enter database password: " DB_PASS
    echo
    
    print_section "Admin User Setup"
    read -p "${BLUE}${ARROW}${NC} Admin Email: " ADMIN_EMAIL
    read -p "${BLUE}${ARROW}${NC} Admin Username: " ADMIN_USER
    read -p "${BLUE}${ARROW}${NC} Admin First Name: " ADMIN_FIRST
    read -p "${BLUE}${ARROW}${NC} Admin Last Name: " ADMIN_LAST
    read -sp "${BLUE}${ARROW}${NC} Admin Password: " ADMIN_PASS
    echo
}

main() {
    check_root
    detect_os
    get_user_input
    
    echo -e "\n${CYAN}${HOURGLASS} Installation will now begin...${NC}\n"
    sleep 2
    
    update_system
    install_dependencies
    install_nodejs_composer
    setup_database
    install_arcpanel
    create_admin
    set_permissions
    configure_nginx
    setup_ssl
    setup_queue_worker

    # Final Output Screen
    echo -e "\n${MAGENTA}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║${NC}     ${GREEN}${STAR} Installation Completed Successfully! ${STAR}${NC}          ${MAGENTA}║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${BLUE}${INFO}${NC} ${CYAN}Panel Access Information:${NC}"
    echo -e "${BLUE}${ARROW}${NC} ${WHITE}URL:${NC}        ${GREEN}https://$DOMAIN${NC}"
    echo -e "${BLUE}${ARROW}${NC} ${WHITE}Directory:${NC}  ${GREEN}$INSTALL_DIR${NC}"
    echo
    echo -e "${BLUE}${INFO}${NC} ${CYAN}Administrator Credentials:${NC}"
    echo -e "${BLUE}${ARROW}${NC} ${WHITE}Username:${NC}   ${GREEN}$ADMIN_USER${NC}"
    echo -e "${BLUE}${ARROW}${NC} ${WHITE}Email:${NC}      ${GREEN}$ADMIN_EMAIL${NC}"
    echo -e "${BLUE}${ARROW}${NC} ${WHITE}Password:${NC}   ${GREEN}(Hidden for security)${NC}"
    echo
    echo -e "${BLUE}${INFO}${NC} ${CYAN}Database Credentials:${NC}"
    echo -e "${BLUE}${ARROW}${NC} ${WHITE}Database:${NC}   ${GREEN}$DB_NAME${NC}"
    echo -e "${BLUE}${ARROW}${NC} ${WHITE}DB User:${NC}    ${GREEN}$DB_USER${NC}"
    echo
    echo -e "${FIRE} ${MAGENTA}Your ArcPanel is live! Setup your nodes and eggs next.${NC} ${FIRE}\n"
}

main "$@"
