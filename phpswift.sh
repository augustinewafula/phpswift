#!/bin/bash

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to show current PHP version
show_current_version() {
    echo -e "${GREEN}Current PHP version:${NC}"
    php -v | grep ^PHP
}

# Function to list available PHP versions
list_versions() {
    echo -e "${GREEN}Available PHP versions:${NC}"
    update-alternatives --list php 2>/dev/null || echo "No PHP versions found in alternatives system"
}

# Function to install PHP and Laravel required extensions
install_php() {
    local version=$1
    if [ -z "$version" ]; then
        echo -e "${RED}Please specify a PHP version (e.g. 7.4, 8.0, 8.1, 8.2)${NC}"
        exit 1
    }

    echo -e "${GREEN}Installing PHP $version and Laravel required extensions...${NC}"
    
    # Add PHP repository
    sudo add-apt-repository ppa:ondrej/php -y
    sudo apt update

    # Install PHP and extensions required for Laravel
    sudo apt install -y \
        php$version \
        php$version-cli \
        php$version-common \
        php$version-fpm \
        php$version-mysql \
        php$version-zip \
        php$version-gd \
        php$version-mbstring \
        php$version-curl \
        php$version-xml \
        php$version-bcmath \
        php$version-soap \
        php$version-intl \
        php$version-readline \
        php$version-ldap \
        php$version-msgpack \
        php$version-igbinary \
        php$version-redis \
        php-xdebug \
        php-memcached

    # Install Composer if not already installed
    if ! command -v composer &> /dev/null; then
        echo -e "${YELLOW}Installing Composer...${NC}"
        EXPECTED_CHECKSUM="$(php -r 'copy("https://composer.github.io/installer.sig", "php://stdout");')"
        php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
        ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

        if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
            echo -e "${RED}Composer installer corrupt${NC}"
            rm composer-setup.php
            exit 1
        fi

        php composer-setup.php --quiet
        rm composer-setup.php
        sudo mv composer.phar /usr/local/bin/composer
    fi

    echo -e "${GREEN}PHP $version and Laravel requirements installed successfully!${NC}"
}

# Function to switch PHP version
switch_version() {
    local version=$1
    if [ -z "$version" ]; then
        echo -e "${RED}Please specify a PHP version (e.g. 7.4, 8.0, 8.1, 8.2)${NC}"
        exit 1
    fi

    # Check if the version exists
    if ! update-alternatives --list php 2>/dev/null | grep -q "/usr/bin/php$version"; then
        echo -e "${YELLOW}PHP $version is not installed. Would you like to install it? (y/n)${NC}"
        read -r answer
        if [ "$answer" != "${answer#[Yy]}" ]; then
            install_php "$version"
        else
            echo -e "${RED}Operation cancelled${NC}"
            exit 1
        fi
    fi

    # Switch PHP version
    sudo update-alternatives --set php /usr/bin/php$version
    sudo update-alternatives --set phar /usr/bin/phar$version
    sudo update-alternatives --set phar.phar /usr/bin/phar.phar$version

    # Handle both Apache and PHP-FPM
    if dpkg -l | grep -q apache2; then
        sudo a2dismod php* 2>/dev/null
        sudo a2enmod php$version
        sudo service apache2 restart
    fi

    if systemctl list-units --full -all | grep -Fq "php$version-fpm"; then
        sudo systemctl restart php$version-fpm
    fi

    # Update PHP CLI configuration
    sudo update-alternatives --set php-config /usr/bin/php-config$version
    sudo update-alternatives --set phpize /usr/bin/phpize$version

    echo -e "${GREEN}Switched to PHP $version${NC}"
    show_current_version
}

# Function to check and display PHP configuration
check_config() {
    echo -e "${GREEN}PHP Configuration for Laravel:${NC}"
    php -r "echo 'PHP Version: ' . phpversion() . \"\n\";"
    echo "Checking required extensions..."
    
    required_extensions=(
        "BCMath" "Ctype" "JSON" "Mbstring" "OpenSSL" "PDO" "Tokenizer" "XML" "CURL" "Fileinfo"
        "MySQL" "Zip" "GD" "Redis" "Memcached"
    )

    for ext in "${required_extensions[@]}"; do
        if php -m | grep -qi "^$ext$"; then
            echo -e "${GREEN}✓ $ext${NC}"
        else
            echo -e "${RED}✗ $ext - Missing!${NC}"
        fi
    done
}

# Show help
show_help() {
    echo -e "${GREEN}PHP Version Switcher for Laravel${NC}"
    echo "Usage:"
    echo "  $(basename "$0") install <version>  - Install PHP version with Laravel extensions"
    echo "  $(basename "$0") switch <version>   - Switch to specified PHP version"
    echo "  $(basename "$0") list               - List installed PHP versions"
    echo "  $(basename "$0") current           - Show current PHP version"
    echo "  $(basename "$0") check             - Check PHP configuration for Laravel"
    echo "  $(basename "$0") help              - Show this help message"
}

# Main script
case "$1" in
    "install")
        install_php "$2"
        ;;
    "switch")
        switch_version "$2"
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
        switch_version "$1"
        ;;
esac
