# PHPSwift 🚀

PHPSwift is a powerful Bash script that simplifies PHP version management for Laravel development environments on Ubuntu/Debian systems. It handles installation, switching between PHP versions, and managing extensions required for Laravel development.

## Features ✨

- Install specific PHP versions with Laravel-required extensions
- Switch between PHP versions seamlessly
- Automatic handling of both Apache and PHP-FPM configurations
- Built-in configuration checker for Laravel requirements
- Composer installation and management
- Support for multiple PHP versions (7.4, 8.0, 8.1, 8.2)
- Color-coded output for better readability

## Prerequisites 🔧

- Ubuntu/Debian-based system
- Sudo privileges
- Basic understanding of PHP version management

## Installation 📥

1. Download the script:
```bash
curl -O https://raw.githubusercontent.com/augustinewafula/phpswift/main/phpswift.sh
```

2. Make it executable:
```bash
chmod +x phpswift.sh
```

3. Optionally, move it to your PATH:
```bash
sudo mv phpswift.sh /usr/local/bin/phpswift
```

## Usage 🛠️

### Install a PHP Version
```bash
./phpswift.sh install 8.2
```
This installs PHP 8.2 along with all necessary Laravel extensions.

### Switch PHP Version
```bash
./phpswift.sh switch 8.1
```
Switches your system to use PHP 8.1.

### List Available PHP Versions
```bash
./phpswift.sh list
```

### Show Current PHP Version
```bash
./phpswift.sh current
```

### Check Laravel Requirements
```bash
./phpswift.sh check
```
Verifies that all required PHP extensions for Laravel are installed.

### Show Help
```bash
./phpswift.sh help
```

## Extensions Included 📦

The script installs these PHP extensions required for Laravel:
- BCMath
- CLI
- Common
- FPM
- MySQL
- ZIP
- GD
- Mbstring
- CURL
- XML
- BCMath
- SOAP
- Intl
- Readline
- LDAP
- Msgpack
- igbinary
- Redis
- Xdebug
- Memcached

## Support for Web Servers 🌐

PHPSwift automatically detects and configures:
- Apache2 (if installed)
- PHP-FPM (if installed)

## Troubleshooting 🔍

If you encounter any issues:

1. Check if you have sufficient permissions:
```bash
sudo ./phpswift.sh [command]
```

2. Verify that the Ondrej PHP repository is properly added:
```bash
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update
```

3. Check Apache/PHP-FPM status:
```bash
sudo systemctl status apache2
sudo systemctl status php*-fpm
```

## Contributing 🤝

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License 📄

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments 🙏

- [Ondrej PHP Repository](https://launchpad.net/~ondrej/+archive/ubuntu/php)
- Laravel Documentation for PHP requirements
- The PHP Community

Made with ❤️ for the Laravel Community
