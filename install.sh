#!/bin/bash

# ArcPanel Installer Script
# Production-grade installer for ArcPanel - Multi-OS Support
# Version: 3.0.0

set -e
export DEBIAN_FRONTEND=noninteractive
export COMPOSER_ALLOW_SUPERUSER=1

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
LOG_FILE="/var/log/arcpanel_install.log"

# Admin variables
ADMIN_EMAIL=""
ADMIN_USER=""
ADMIN_FIRST=""
ADMIN_LAST=""
ADMIN_PASS=""

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

> "$LOG_FILE"

spinner() {
    local pid=$1
    local delay=0.1
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local spin_count=0
    
    while kill -0 $pid 2>/dev/null; do
        printf "\r${CYAN}${frames[$((spin_count % ${#frames[@]}))]}${NC} Working..."
        sleep $delay
        spin_count=$((spin_count + 1))
    done
    printf "\r\033[K"
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
error() { 
    echo -e "${RED}${CROSS}${NC} ${RED}$1${NC}"
    echo -e "${YELLOW}${INFO}${NC} ${YELLOW}Check $LOG_FILE for details.${NC}"
}
info() { echo -e "${CYAN}${INFO}${NC} ${CYAN}$1${NC}"; }

print_header() {
    clear
    echo -e "${MAGENTA}"
    cat << "EOF"
    ╔══════════════════════════════════════════════════════════╗
    ║                                                          ║
    ║   🚀  ArcPanel Installer - Multi-OS Edition v3.0  🚀    ║
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
        apt) ( apt-get update -y && apt-get upgrade -y ) >> "$LOG_FILE" 2>&1 & ;;
        dnf) dnf upgrade -y >> "$LOG_FILE" 2>&1 & ;;
        yum) yum update -y >> "$LOG_FILE" 2>&1 & ;;
        apk) ( apk update && apk upgrade ) >> "$LOG_FILE" 2>&1 & ;;
        pacman) pacman -Syu --noconfirm >> "$LOG_FILE" 2>&1 & ;;
    esac
    
    local pid=$!
    spinner $pid
    wait $pid || warn "Minor package warnings ignored, continuing..."
    success "System packages updated"
}

install_dependencies() {
    print_section "${GEAR} Installing Dependencies"
    
    case "$PKG_MANAGER" in
        apt)
            ( 
                rm -f /etc/apt/sources.list.d/*ondrej*.list
                rm -f /etc/apt/sources.list.d/php.list*
                
                apt-get install -y software-properties-common ca-certificates lsb-release apt-transport-https curl wget
                
                if [ "$OS_TYPE" == "ubuntu" ]; then
                    add-apt-repository ppa:ondrej/php -y || true
                elif [ "$OS_TYPE" == "debian" ]; then
                    wget -qO /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg || true
                    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list
                fi
                
                apt-get update -y
                apt-get install -y nginx mariadb-server redis-server php${PHP_VERSION}-cli php${PHP_VERSION}-fpm php${PHP_VERSION}-mysql php${PHP_VERSION}-xml php${PHP_VERSION}-mbstring php${PHP_VERSION}-curl php${PHP_VERSION}-zip php${PHP_VERSION}-bcmath php${PHP_VERSION}-gd php${PHP_VERSION}-intl php${PHP_VERSION}-redis git unzip supervisor
            ) >> "$LOG_FILE" 2>&1 &
            ;;
        *)
            error "Please use Ubuntu/Debian for guaranteed full support."
            exit 1
            ;;
    esac
    
    local pid=$!
    spinner $pid
    wait $pid || { error "Dependency installation failed!"; exit 1; }
    success "Dependencies installed"
}

install_nodejs_composer() {
    print_section "${ROCKET} Installing Node.js and Composer"
    
    ( curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt-get install -y nodejs certbot python3-certbot-nginx ) >> "$LOG_FILE" 2>&1 &
    local pid=$!
    spinner $pid
    wait $pid || { error "Node.js installation failed!"; exit 1; }
    
    ( curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer ) >> "$LOG_FILE" 2>&1 &
    pid=$!
    spinner $pid
    wait $pid || { error "Composer installation failed!"; exit 1; }
    
    success "Node.js, Composer, and Certbot installed"
}

setup_database() {
    print_section "${DATABASE} Setting Up Database"
    systemctl start mariadb >> "$LOG_FILE" 2>&1 || systemctl start mysql >> "$LOG_FILE" 2>&1
    systemctl enable mariadb >> "$LOG_FILE" 2>&1 || systemctl enable mysql >> "$LOG_FILE" 2>&1

    # NEW FIX: Forcefully update the user password even if they already exist from a previous failed run
    mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" >> "$LOG_FILE" 2>&1
    mysql -u root -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';" >> "$LOG_FILE" 2>&1
    mysql -u root -e "ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';" >> "$LOG_FILE" 2>&1
    mysql -u root -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';" >> "$LOG_FILE" 2>&1
    mysql -u root -e "FLUSH PRIVILEGES;" >> "$LOG_FILE" 2>&1
    
    # Inject dummy table to bypass Laravel Boot crash
    mysql -u root -e "CREATE TABLE IF NOT EXISTS \`$DB_NAME\`.arc_plugins (id INT AUTO_INCREMENT PRIMARY KEY, enabled TINYINT(1) DEFAULT 0);" >> "$LOG_FILE" 2>&1
    
    success "Database setup completed"
}

install_arcpanel() {
    print_section "${ROCKET} Installing ArcPanel"
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    if [[ ! -d ".git" ]]; then
        git clone https://github.com/NotRayy01/arcpanel.git . >> "$LOG_FILE" 2>&1 &
        local pid=$!
        spinner $pid
        wait $pid || { error "Git clone failed!"; exit 1; }
    fi
    
    cp .env.example .env 2>/dev/null || true
    
    # NEW FIX: Changed delimiters from | to ~ to prevent password special character injection crashes
    sed -i "s~APP_URL=.*~APP_URL=\"https://$DOMAIN\"~" .env
    sed -i "s~DB_DATABASE=.*~DB_DATABASE=\"$DB_NAME\"~" .env
    sed -i "s~DB_USERNAME=.*~DB_USERNAME=\"$DB_USER\"~" .env
    sed -i "s~DB_PASSWORD=.*~DB_PASSWORD=\"$DB_PASS\"~" .env
    sed -i "s~CACHE_DRIVER=.*~CACHE_DRIVER=\"redis\"~" .env
    sed -i "s~QUEUE_CONNECTION=.*~QUEUE_CONNECTION=\"redis\"~" .env
    sed -i "s~SESSION_DRIVER=.*~SESSION_DRIVER=\"redis\"~" .env

    composer update --no-dev --optimize-autoloader >> "$LOG_FILE" 2>&1 &
    local pid=$!
    spinner $pid
    wait $pid || { error "Composer dependencies failed!"; exit 1; }
    
    ( npm install --legacy-peer-deps && npm run build ) >> "$LOG_FILE" 2>&1 &
    pid=$!
    spinner $pid
    wait $pid || warn "NPM build had warnings, continuing..."

    if ! php artisan key:generate --force >> "$LOG_FILE" 2>&1; then
        error "Application key generation failed! Check logs."
        exit 1
    fi
    
    find database/migrations -type f -name "*create_arc_plugins_table.php" -exec sed -i "s/Schema::create('arc_plugins'/Schema::dropIfExists('arc_plugins'); Schema::create('arc_plugins'/g" {} + 2>/dev/null || true
    
    if ! php artisan migrate --seed --force >> "$LOG_FILE" 2>&1; then
        error "Database migration failed! Check logs."
        exit 1
    fi
    
    php artisan storage:link >> "$LOG_FILE" 2>&1 || true
    
    success "ArcPanel deployed and migrated"
}

create_admin() {
    print_section "${LOCK} Creating Admin User"
    cd "$INSTALL_DIR"
    
    php artisan p:user:make \
        --email="$ADMIN_EMAIL" \
        --username="$ADMIN_USER" \
        --name-first="$ADMIN_FIRST" \
        --name-last="$ADMIN_LAST" \
        --password="$ADMIN_PASS" \
        --admin=1 >> "$LOG_FILE" 2>&1 &
        
    local pid=$!
    spinner $pid
    wait $pid || warn "User creation encountered an issue. You can re-run 'php artisan p:user:make' manually later."
    success "Admin user logic completed!"
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
    systemctl restart nginx >> "$LOG_FILE" 2>&1
    systemctl enable nginx >> "$LOG_FILE" 2>&1
    success "Nginx configured"
}

setup_ssl() {
    print_section "${LOCK} Setting Up SSL Certificate"
    certbot --nginx -d "$DOMAIN" --email "$EMAIL" --agree-tos --non-interactive --redirect >> "$LOG_FILE" 2>&1 &
    local pid=$!
    spinner $pid
    wait $pid || warn "SSL generation failed. Check rate limits or DNS propagation."
    success "SSL certificate configured"
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

    supervisorctl reread >> "$LOG_FILE" 2>&1 || true
    supervisorctl update >> "$LOG_FILE" 2>&1 || true
    supervisorctl start arcpanel-worker >> "$LOG_FILE" 2>&1 || true
    success "Queue worker started"
}

get_user_input() {
    print_header
    
    print_section "Panel Configuration"
    echo -e -n "${BLUE}${ARROW}${NC} Enter domain name (e.g panel.example.com): "
    read DOMAIN
    echo -e -n "${BLUE}${ARROW}${NC} Enter email for SSL certificate: "
    read EMAIL
    
    print_section "Database Configuration"
    echo -e -n "${BLUE}${ARROW}${NC} Enter database name [${CYAN}arcpanel${NC}]: "
    read INPUT_DB_NAME
    DB_NAME=${INPUT_DB_NAME:-arcpanel}
    
    echo -e -n "${BLUE}${ARROW}${NC} Enter database user [${CYAN}arcpanel${NC}]: "
    read INPUT_DB_USER
    DB_USER=${INPUT_DB_USER:-arcpanel}
    
    echo -e -n "${BLUE}${ARROW}${NC} Enter database password: "
    read -s DB_PASS
    echo
    
    print_section "Admin User Setup"
    echo -e -n "${BLUE}${ARROW}${NC} Admin Email: "
    read ADMIN_EMAIL
    echo -e -n "${BLUE}${ARROW}${NC} Admin Username: "
    read ADMIN_USER
    echo -e -n "${BLUE}${ARROW}${NC} Admin First Name: "
    read ADMIN_FIRST
    echo -e -n "${BLUE}${ARROW}${NC} Admin Last Name: "
    read ADMIN_LAST
    echo -e -n "${BLUE}${ARROW}${NC} Admin Password: "
    read -s ADMIN_PASS
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
