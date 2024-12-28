#!/usr/bin/env bash
#
# PHP Version Switcher for Laravel
#

###############################################################################
# Safety settings: fail on unset variables and on error. Also handle pipefails.
###############################################################################
set -euo pipefail
IFS=$'\n\t'

###############################################################################
# Colors for better readability
###############################################################################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

###############################################################################
# Logging & status output
###############################################################################
LOGFILE="/var/log/php-switcher.log"

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    echo "[ERROR] $1" >> "$LOGFILE"
}

info() {
    echo -e "${GREEN}[INFO] $1${NC}"
    echo "[INFO] $1" >> "$LOGFILE"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
    echo "[WARNING] $1" >> "$LOGFILE"
}

###############################################################################
# Global / default variables
###############################################################################
DRY_RUN=0

# You can tweak this host if you prefer to test connectivity with something else
PING_HOST="google.com"

# Storing supported PHP versions in one array
SUPPORTED_VERSIONS=("7.2" "7.3" "7.4" "8.0" "8.1" "8.2" "8.3")

###############################################################################
# Parse arguments for --dry-run (and anything else you want to support globally)
###############################################################################
for arg in "$@"; do
    if [ "$arg" = "--dry-run" ]; then
        DRY_RUN=1
    fi
done

###############################################################################
# Check for required commands
###############################################################################
check_prerequisites() {
    # List all critical commands that must exist
    local commands=("apt" "dpkg" "sudo" "ping" "systemctl" "service")

    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            error "$cmd not found. Please install it or ensure it's in your PATH."
            exit 1
        fi
    done
}

###############################################################################
# Check for root privileges
###############################################################################
require_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Please run this script as root or via sudo."
        exit 1
    fi
}

###############################################################################
# Validate PHP version format using a simple regex like XX.Y
###############################################################################
validate_version() {
    local version=$1
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+$ ]]; then
        error "Invalid version format '$version'. Expected something like '7.4' or '8.1'."
        exit 1
    fi
}

###############################################################################
# Provide a simple backup for Apache conf
###############################################################################
backup_conf() {
    local conf_name=$1
    local conf_path="/etc/apache2/conf-available/${conf_name}.conf"
    if [ -f "$conf_path" ]; then
        local backup_path="${conf_path}.bak_$(date +%s)"
        if [ $DRY_RUN -eq 1 ]; then
            warn "Dry-run: would have backed up $conf_path to $backup_path"
        else
            cp "$conf_path" "$backup_path"
            info "Backed up $conf_path to $backup_path"
        fi
    fi
}

###############################################################################
# Graceful restart or reload of services
###############################################################################
restart_service() {
    local service_name=$1

    if command -v systemctl &>/dev/null; then
        if [ $DRY_RUN -eq 1 ]; then
            warn "Dry-run: would run 'systemctl restart $service_name'"
            return 0
        fi
        if systemctl restart "$service_name"; then
            info "Service $service_name restarted successfully using systemctl"
        else
            warn "systemctl failed to restart $service_name, trying 'service' command..."
            if service "$service_name" restart; then
                info "Service $service_name restarted successfully using 'service' command"
            else
                error "Failed to restart $service_name with both systemctl and service commands"
            fi
        fi
    else
        warn "systemctl not found; trying 'service' command..."
        if [ $DRY_RUN -eq 1 ]; then
            warn "Dry-run: would run 'service $service_name restart'"
            return 0
        fi
        if service "$service_name" restart; then
            info "Service $service_name restarted successfully using 'service' command"
        else
            error "Failed to restart $service_name with 'service' command"
        fi
    fi
}

reload_service() {
    local service_name=$1

    if command -v systemctl &>/dev/null; then
        if [ $DRY_RUN -eq 1 ]; then
            warn "Dry-run: would run 'systemctl reload $service_name'"
            return 0
        fi
        if systemctl reload "$service_name"; then
            info "Service $service_name reloaded successfully using systemctl"
        else
            warn "systemctl failed to reload $service_name, trying 'service' command..."
            if service "$service_name" reload; then
                info "Service $service_name reloaded successfully using 'service' command"
            else
                error "Failed to reload $service_name with both systemctl and service commands"
            fi
        fi
    else
        warn "systemctl not found; trying 'service' command..."
        if [ $DRY_RUN -eq 1 ]; then
            warn "Dry-run: would run 'service $service_name reload'"
            return 0
        fi
        if service "$service_name" reload; then
            info "Service $service_name reloaded successfully using 'service' command"
        else
            error "Failed to reload $service_name with 'service' command"
        fi
    fi
}

###############################################################################
# Check internet connectivity
###############################################################################
check_internet() {
    # Try ping first; if that fails, you could optionally try curl or some other check.
    if ! ping -c 1 -q "$PING_HOST" &>/dev/null; then
        error "No internet connection detected. Please check your network."
        exit 1
    fi
}

###############################################################################
# Show current PHP version (CLI)
###############################################################################
show_current_version() {
    info "Current PHP version (CLI):"
    php -v | grep ^PHP || true
}

###############################################################################
# List available PHP versions via update-alternatives
###############################################################################
list_versions() {
    info "Available PHP versions (via update-alternatives):"
    update-alternatives --list php 2>/dev/null || echo "No PHP versions found in alternatives system"
}

###############################################################################
# Install PHP with Laravel required extensions
###############################################################################
install_php() {
    local version=$1

    # Validate version format
    validate_version "$version"

    # Check internet connectivity
    check_internet

    info "Installing PHP $version and Laravel required extensions..."

    # Ensure add-apt-repository is available
    if ! command -v add-apt-repository &>/dev/null; then
        warn "Installing software-properties-common..."
        if [ $DRY_RUN -eq 1 ]; then
            warn "Dry-run: would run 'apt install -y software-properties-common'"
        else
            apt install -y software-properties-common >> "$LOGFILE" 2>&1 || {
                error "Failed to install software-properties-common"
            }
        fi
    fi

    # Add PHP repository
    if [ $DRY_RUN -eq 1 ]; then
        warn "Dry-run: would run 'add-apt-repository ppa:ondrej/php -y' and 'apt update'"
    else
        add-apt-repository ppa:ondrej/php -y >> "$LOGFILE" 2>&1 || {
            error "Failed to add ppa:ondrej/php"
        }
        apt update >> "$LOGFILE" 2>&1 || {
            error "Failed to update packages"
        }
    fi

    # List of extensions needed by Laravel
    local extensions=(cli common fpm mysql zip gd mbstring curl xml bcmath soap intl readline ldap msgpack igbinary redis xdebug memcached)

    # Track installed/failed for summary
    local installed_extensions=()
    local failed_extensions=()

    for ext in "${extensions[@]}"; do
        local pkg="php${version}-${ext}"
        if [ $DRY_RUN -eq 1 ]; then
            warn "Dry-run: would run 'apt install -y $pkg'"
        else
            info "Installing $pkg..."
            if apt install -y "$pkg" >> "$LOGFILE" 2>&1; then
                installed_extensions+=("$pkg")
            else
                warn "Skipping unavailable or failed extension: $pkg"
                failed_extensions+=("$pkg")
            fi
        fi
    done

    # If Apache is installed, also install libapache2-mod-php
    if dpkg -l | grep -q apache2; then
        local mod_pkg="libapache2-mod-php$version"
        if [ $DRY_RUN -eq 1 ]; then
            warn "Dry-run: would run 'apt install -y $mod_pkg'"
        else
            info "Detected Apache. Installing $mod_pkg..."
            if apt install -y "$mod_pkg" >> "$LOGFILE" 2>&1; then
                installed_extensions+=("$mod_pkg")
            else
                failed_extensions+=("$mod_pkg")
                error "Failed to install $mod_pkg"
            fi
        fi
    fi

    # Install Composer if not already installed
    if ! command -v composer &>/dev/null; then
        warn "Installing Composer..."
        if [ $DRY_RUN -eq 1 ]; then
            warn "Dry-run: would download and install composer."
        else
            # Verify composer installer signature
            EXPECTED_CHECKSUM="$(php -r 'copy("https://composer.github.io/installer.sig", "php://stdout");')"
            php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
            ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

            if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
                error "Composer installer corrupt. Aborting."
                rm composer-setup.php
                exit 1
            fi

            php composer-setup.php --quiet
            rm composer-setup.php
            mv composer.phar /usr/local/bin/composer
        fi
    fi

    # Summaries
    info "PHP $version installation attempt completed."
    if [ ${#installed_extensions[@]} -gt 0 ]; then
        info "Installed successfully: ${installed_extensions[*]}"
    fi
    if [ ${#failed_extensions[@]} -gt 0 ]; then
        warn "Failed to install: ${failed_extensions[*]}"
    fi

    info "PHP $version and Laravel requirements installation finished (check logs for details)."
}

###############################################################################
# Install FPM if missing and configure services
###############################################################################
install_fpm_if_missing() {
    local version=$1

    if ! dpkg -l | grep -q "php${version}-fpm"; then
        warn "PHP ${version}-fpm is not installed. Installing..."

        if [ $DRY_RUN -eq 1 ]; then
            warn "Dry-run: would install php${version}-fpm."
        else
            apt install -y "php${version}-fpm" >> "$LOGFILE" 2>&1 || {
                error "Failed to install php${version}-fpm."
                exit 1
            }
            info "PHP ${version}-fpm installed successfully."
        fi
    else
        info "PHP ${version}-fpm is already installed."
    fi

    # Ensure the new version's FPM service is enabled
    if [ $DRY_RUN -eq 1 ]; then
        warn "Dry-run: would enable php${version}-fpm service."
    else
        systemctl enable "php${version}-fpm" >> "$LOGFILE" 2>&1 || {
            error "Failed to enable php${version}-fpm service."
            exit 1
        }
    fi
}

###############################################################################
# Disable old FPM services
###############################################################################
disable_old_fpm_services() {
    local new_version=$1

    for oldver in "${SUPPORTED_VERSIONS[@]}"; do
        if [ "$oldver" != "$new_version" ]; then
            local service_name="php${oldver}-fpm"

            # Thoroughly check for the service, including checking specific paths
            if systemctl list-units --type=service --all | grep -q "$service_name" || [ -f "/lib/systemd/system/$service_name.service" ] || [ -f "/etc/systemd/system/$service_name.service" ]; then
                info "Disabling old FPM service: $service_name..."

                if [ $DRY_RUN -eq 1 ]; then
                    warn "Dry-run: would stop and disable $service_name."
                else
                    systemctl stop "$service_name" >> "$LOGFILE" 2>&1 || {
                        warn "Failed to stop $service_name."
                    }
                    systemctl disable "$service_name" >> "$LOGFILE" 2>&1 || {
                        warn "Failed to disable $service_name."
                    }
                fi

                # Disable old php-fpm conf in Apache (if it exists)
                if [ -f "/etc/apache2/conf-available/${service_name}.conf" ]; then

                    if [ $DRY_RUN -eq 1 ]; then
                        warn "Dry-run: would run 'a2disconf ${service_name}'"
                    else
                        a2disconf "$service_name" >> "$LOGFILE" 2>&1 || {
                            warn "Failed to disable Apache configuration for $service_name."
                        }
                    fi
                fi
            fi
        fi
    done
}

###############################################################################
# Switch PHP version (CLI + mod-php/FPM)
###############################################################################
switch_version() {
    local version=$1
    validate_version "$version"

    echo -e "${YELLOW}You are about to switch to PHP $version. Continue? (y/n)${NC}"
    read -r confirm_switch
    case "$confirm_switch" in
        [Yy]* ) info "Switching to PHP $version..." ;;
        [Nn]* | "" )
            info "Switch cancelled."
            exit 0
            ;;
        * )
            warn "Invalid input. Operation cancelled."
            exit 1
            ;;
    esac

    # Install FPM if missing
    install_fpm_if_missing "$version"

    # Disable old FPM services
    disable_old_fpm_services "$version"

    # Enable new php-fpm conf in Apache (if it exists)
    if [ -f "/etc/apache2/conf-available/php${version}-fpm.conf" ]; then
        info "Enabling php${version}-fpm.conf..."
        if [ $DRY_RUN -eq 1 ]; then
            warn "Dry-run: would run 'a2enconf php${version}-fpm'"
        else
            a2enconf "php${version}-fpm" >> "$LOGFILE" 2>&1 || true
            reload_service "apache2"
        fi
    fi

    # Enable & restart the new FPM service
    if [ $DRY_RUN -eq 1 ]; then
        warn "Dry-run: would run 'restart_service php${version}-fpm'"
    else
        restart_service "php${version}-fpm"
    fi

    # Switch CLI binaries via update-alternatives
    local cli_tools=(php phar phar.phar php-config phpize)
    for tool in "${cli_tools[@]}"; do
        if [ -f "/usr/bin/${tool}${version}" ]; then
            if [ $DRY_RUN -eq 1 ]; then
                warn "Dry-run: would run 'update-alternatives --set $tool /usr/bin/${tool}${version}'"
            else
                info "Setting alternative for $tool to /usr/bin/${tool}${version}"
                update-alternatives --set "$tool" "/usr/bin/${tool}${version}" >> "$LOGFILE" 2>&1 || {
                    warn "Failed to set alternative for $tool"
                }
            fi
        fi
    done

    info "Switched to PHP $version (CLI)."
    show_current_version

    warn "NOTE: If your web server is configured to use PHP-FPM (via sockets), ensure your server config points to:"
    warn "      /run/php/php${version}-fpm.sock (or equivalent). Then reload/restart your web server for changes."
}

###############################################################################
# Check and display PHP configuration for Laravel
###############################################################################
check_config() {
    info "PHP Configuration for Laravel:"
    php -r "echo 'PHP Version: ' . phpversion() . \"\n\";" || true
    echo "Checking required extensions..."

    # Basic extension checks
    local required_extensions=("BCMath" "Ctype" "JSON" "Mbstring" "OpenSSL" "PDO" "Tokenizer" "XML" "CURL" "Fileinfo" "MySQL" "Zip" "GD" "Redis" "Memcached")

    for ext in "${required_extensions[@]}"; do
        if php -m | grep -qi "^$ext$"; then
            echo -e "${GREEN}✓ $ext${NC}"
        else
            echo -e "${RED}✗ $ext - Missing!${NC}"
        fi
    done
}

###############################################################################
# Uninstall PHP
###############################################################################
uninstall_php() {
    local version=$1
    validate_version "$version"

    echo -e "${YELLOW}Are you sure you want to remove PHP $version packages? This is destructive. (y/n)${NC}"
    read -r confirmation
    case "$confirmation" in
        [Yy]* )
            info "Proceeding with PHP $version uninstallation..."
            ;;
        [Nn]* | "" )
            info "Uninstallation cancelled."
            exit 0
            ;;
        * )
            warn "Invalid input. Operation cancelled."
            exit 1
            ;;
    esac

    warn "Uninstalling PHP $version..."
    local pkg_pattern="php${version}*"
    if [ $DRY_RUN -eq 1 ]; then
        warn "Dry-run: would run 'apt purge -y $pkg_pattern' and 'apt autoremove -y'"
    else
        if ! apt purge -y $pkg_pattern >> "$LOGFILE" 2>&1; then
            error "Failed to uninstall some components of PHP $version"
        fi
        apt autoremove -y >> "$LOGFILE" 2>&1 || true
    fi

    info "PHP $version uninstalled successfully (check logs for details)."
}

###############################################################################
# Show help
###############################################################################
show_help() {
    echo -e "${GREEN}PHP Version Switcher for Laravel (Improved)${NC}"
    echo "Usage:"
    echo "  $(basename "$0") install <version>    - Install PHP version with Laravel extensions"
    echo "  $(basename "$0") switch <version>     - Switch to specified PHP version (CLI + mod-PHP/FPM)"
    echo "  $(basename "$0") uninstall <version>  - Uninstall specified PHP version"
    echo "  $(basename "$0") list                 - List installed PHP versions"
    echo "  $(basename "$0") current              - Show current PHP version (CLI)"
    echo "  $(basename "$0") check                - Check PHP configuration for Laravel"
    echo "  $(basename "$0") help                 - Show this help message"
    echo
    echo "Options:"
    echo "  --dry-run    Display what actions would be performed, without changing the system"
    echo
    echo "Examples:"
    echo "  $(basename "$0") install 7.4          # Installs PHP 7.4 with all required extensions"
    echo "  $(basename "$0") switch 8.1           # Switches system to use PHP 8.1"
    echo "  $(basename "$0") --dry-run install 8.2 # Dry-run installing PHP 8.2 (no actual changes)"
    echo
    echo "Note: This script is intended for Debian/Ubuntu-based systems with apt/dpkg."
}

###############################################################################
# Main script logic
###############################################################################
main() {
    # Check prerequisites and require root
    check_prerequisites
    require_root

    local cmd="${1:-help}"  # if no arg is passed, default to help
    local arg2="${2:-}"

    case "$cmd" in
        "install")
            install_php "$arg2"
            ;;
        "switch")
            switch_version "$arg2"
            ;;
        "uninstall")
            uninstall_php "$arg2"
            ;;
        "list")
            list_versions
            ;;
        "current")
            show_current_version
            ;;
        "check")
            check_config
            ;;
        "help"|"")
            show_help
            ;;
        *)
            error "Invalid option '$cmd'. Use 'help' for usage instructions."
            ;;
    esac
}

###############################################################################
# Entry point
###############################################################################
main "$@"
