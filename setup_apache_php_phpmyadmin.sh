#!/usr/bin/env bash
# ===============================================
#  Apache + PHP + phpMyAdmin setup for Arch Linux
#  (MariaDB already installed)
# ===============================================

set -e

echo "=== Updating system ==="
sudo pacman -Syu --noconfirm

echo "=== Installing Apache, PHP, and phpMyAdmin ==="
sudo pacman -S --noconfirm apache php php-apache phpmyadmin

echo "=== Enabling Apache service ==="
sudo systemctl enable httpd

HTTPD_CONF="/etc/httpd/conf/httpd.conf"

# Backup old config if not yet done
if [ ! -f "${HTTPD_CONF}.bak" ]; then
  sudo cp "$HTTPD_CONF" "${HTTPD_CONF}.bak"
fi

echo "=== Writing Apache configuration ==="
sudo bash -c "cat > $HTTPD_CONF" <<'CONF'
# ==========================================
#  Apache HTTPD Configuration (Arch Linux)
# ==========================================

ServerRoot "/etc/httpd"
Listen 80
ServerName localhost

# Use prefork MPM (required for non-thread-safe PHP)
# Comment out event and worker if present
LoadModule mpm_prefork_module modules/mod_mpm_prefork.so

# Core modules
LoadModule authn_file_module modules/mod_authn_file.so
LoadModule authn_core_module modules/mod_authn_core.so
LoadModule authz_core_module modules/mod_authz_core.so
LoadModule authz_host_module modules/mod_authz_host.so
LoadModule access_compat_module modules/mod_access_compat.so
LoadModule auth_basic_module modules/mod_auth_basic.so
LoadModule reqtimeout_module modules/mod_reqtimeout.so
LoadModule filter_module modules/mod_filter.so
LoadModule mime_module modules/mod_mime.so
LoadModule log_config_module modules/mod_log_config.so
LoadModule env_module modules/mod_env.so
LoadModule headers_module modules/mod_headers.so
LoadModule setenvif_module modules/mod_setenvif.so
LoadModule version_module modules/mod_version.so
LoadModule unixd_module modules/mod_unixd.so
LoadModule status_module modules/mod_status.so
LoadModule autoindex_module modules/mod_autoindex.so
LoadModule negotiation_module modules/mod_negotiation.so
LoadModule dir_module modules/mod_dir.so
LoadModule alias_module modules/mod_alias.so
LoadModule userdir_module modules/mod_userdir.so

# Load PHP module
LoadModule php_module modules/libphp.so

User http
Group http
ServerAdmin you@example.com

<Directory />
    AllowOverride none
    Require all denied
</Directory>

DocumentRoot "/srv/http"
<Directory "/srv/http">
    Options Indexes FollowSymLinks
    AllowOverride None
    Require all granted
</Directory>

<IfModule dir_module>
    DirectoryIndex index.php index.html
</IfModule>

<Files ".ht*">
    Require all denied
</Files>

ErrorLog "/var/log/httpd/error_log"
LogLevel warn
CustomLog "/var/log/httpd/access_log" common

# ==========================================
#  PHPMyAdmin setup
# ==========================================
Alias /phpmyadmin "/usr/share/webapps/phpMyAdmin"
<Directory "/usr/share/webapps/phpMyAdmin">
    DirectoryIndex index.php
    Options FollowSymLinks
    AllowOverride None
    Require all granted

    <IfModule php_module>
        AddType application/x-httpd-php .php
        AddHandler php-script .php
    </IfModule>
</Directory>

# ==========================================
#  MIME settings
# ==========================================
<IfModule mime_module>
    TypesConfig conf/mime.types
    AddType application/x-compress .Z
    AddType application/x-gzip .gz .tgz
</IfModule>

Include conf/extra/httpd-mpm.conf
Include conf/extra/httpd-autoindex.conf
Include conf/extra/httpd-default.conf
IncludeOptional conf/conf.d/*.conf

<IfModule ssl_module>
SSLRandomSeed startup builtin
SSLRandomSeed connect builtin
</IfModule>
CONF

echo "=== Restarting Apache ==="
sudo systemctl restart httpd

echo "=== Setup complete ==="
echo "Access phpMyAdmin at:  http://127.0.0.1/phpmyadmin"

