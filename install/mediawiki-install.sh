#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: Community
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://www.mediawiki.org/

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  curl \
  wget \
  sudo \
  gnupg2 \
  ca-certificates \
  lsb-release \
  debian-archive-keyring \
  apt-transport-https \
  imagemagick \
  unzip
msg_ok "Installed Dependencies"

msg_info "Installing Nginx"
$STD apt-get install -y nginx
systemctl enable -q --now nginx
msg_ok "Installed Nginx"

msg_info "Installing PHP 8.2"
$STD apt-get install -y \
  php8.2-fpm \
  php8.2-cli \
  php8.2-common \
  php8.2-mbstring \
  php8.2-xml \
  php8.2-pgsql \
  php8.2-curl \
  php8.2-gd \
  php8.2-intl \
  php8.2-zip \
  php8.2-opcache \
  php8.2-apcu \
  php8.2-redis
msg_ok "Installed PHP 8.2"

msg_info "Installing PostgreSQL"
$STD apt-get install -y postgresql postgresql-contrib
systemctl enable -q --now postgresql
msg_ok "Installed PostgreSQL"

msg_info "Setting up PostgreSQL Database"
DB_NAME="mediawikidb"
DB_USER="mediawiki"
DB_PASS="$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 16)"

sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';" >/dev/null
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;" >/dev/null
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;" >/dev/null

# Configure PostgreSQL to allow local connections
cat <<EOF > /etc/postgresql/*/main/pg_hba.conf
# PostgreSQL Client Authentication Configuration File
local   all             postgres                                peer
local   all             all                                     peer
host    all             all             127.0.0.1/32            scram-sha-256
host    all             all             ::1/128                 scram-sha-256
host    $DB_NAME        $DB_USER        127.0.0.1/32            scram-sha-256
host    $DB_NAME        $DB_USER        ::1/128                 scram-sha-256
EOF

systemctl restart postgresql
echo "${DB_NAME}" >/root/mediawiki.db
echo "${DB_USER}" >>/root/mediawiki.db
echo "${DB_PASS}" >>/root/mediawiki.db
msg_ok "Set up PostgreSQL Database"

msg_info "Installing Redis"
$STD apt-get install -y redis-server
systemctl enable -q --now redis-server
# Configure Redis for MediaWiki sessions
sed -i 's/^# maxmemory .*/maxmemory 256mb/' /etc/redis/redis.conf
sed -i 's/^# maxmemory-policy .*/maxmemory-policy allkeys-lru/' /etc/redis/redis.conf
systemctl restart redis-server
msg_ok "Installed Redis"

msg_info "Installing MediaWiki"
RELEASE=$(curl -s https://www.mediawiki.org/wiki/Download | grep -oP 'MediaWiki \K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
if [ -z "$RELEASE" ]; then
  RELEASE="1.45.3"  # Fallback to stable version
  msg_info "Using fallback version ${RELEASE}"
fi

cd /tmp
msg_info "Downloading MediaWiki ${RELEASE}"
wget -q https://releases.wikimedia.org/mediawiki/${RELEASE%.*}/mediawiki-${RELEASE}.tar.gz
if [ $? -ne 0 ]; then
  msg_error "Failed to download MediaWiki ${RELEASE}"
  exit 1
fi
tar -xzf mediawiki-${RELEASE}.tar.gz
if [ ! -d "mediawiki-${RELEASE}" ]; then
  msg_error "Failed to extract MediaWiki archive"
  exit 1
fi
mkdir -p /var/www
mv mediawiki-${RELEASE} /var/www/mediawiki
rm mediawiki-${RELEASE}.tar.gz
chown -R www-data:www-data /var/www/mediawiki
echo "${RELEASE}" >/root/mediawiki.version
msg_ok "Installed MediaWiki ${RELEASE}"

msg_info "Configuring Nginx"
cat <<'EOF' >/etc/nginx/sites-available/mediawiki
server {
    listen 80;
    listen [::]:80;
    server_name _;

    root /var/www/mediawiki;
    index index.php;

    client_max_body_size 100M;

    # Security headers
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;

    location / {
        try_files $uri $uri/ @rewrite;
    }

    location @rewrite {
        rewrite ^/(.*)$ /index.php?title=$1&$args;
    }

    # Block direct access to images directory (except through MediaWiki)
    location ^~ /images/ {
        # Prevent execution of PHP and other scripts
        location ~ \.(php|php5|phtml|pl|py|jsp|asp|sh|cgi)$ {
            deny all;
        }
        # Allow only specific image file types
        location ~* \.(gif|png|jpg|jpeg|webp|svg|ico)$ {
            add_header X-Content-Type-Options "nosniff" always;
            try_files $uri =404;
        }
        # Deny everything else
        deny all;
    }

    location ^~ /maintenance/ {
        return 403;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires max;
        log_not_found off;
        add_header X-Content-Type-Options "nosniff" always;
    }

    location ~ /\.ht {
        deny all;
    }

    # Block access to sensitive files
    location ~* \.(sql|log|conf|ini|bak|old)$ {
        deny all;
    }
}
EOF

ln -sf /etc/nginx/sites-available/mediawiki /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
$STD nginx -t
systemctl reload nginx
msg_ok "Configured Nginx"

msg_info "Securing images directory"
# Create .htaccess file to prevent script execution in images directory
cat <<'HTACCESS' >/var/www/mediawiki/images/.htaccess
# Prevent execution of PHP and other scripts
<FilesMatch "\.(php|php5|phtml|pl|py|jsp|asp|sh|cgi|exe)$">
    Require all denied
</FilesMatch>

# Only allow image files
<FilesMatch "\.(gif|png|jpg|jpeg|webp|svg|ico)$">
    Require all granted
</FilesMatch>

# Deny access to everything else
<RequireAll>
    Require all denied
</RequireAll>
HTACCESS

chown www-data:www-data /var/www/mediawiki/images/.htaccess
chmod 644 /var/www/mediawiki/images/.htaccess
msg_ok "Secured images directory"

msg_info "Configuring PHP"
# Optimize PHP for MediaWiki
sed -i 's/^memory_limit = .*/memory_limit = 256M/' /etc/php/8.2/fpm/php.ini
sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 100M/' /etc/php/8.2/fpm/php.ini
sed -i 's/^post_max_size = .*/post_max_size = 100M/' /etc/php/8.2/fpm/php.ini
sed -i 's/^max_execution_time = .*/max_execution_time = 300/' /etc/php/8.2/fpm/php.ini
systemctl restart php8.2-fpm
msg_ok "Configured PHP"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"

msg_info "MediaWiki Installation Complete"
echo -e "\n${CREATING}${GN}MediaWiki has been installed successfully!${CL}\n"
echo -e "${INFO}${YW}Database Credentials (saved to /root/mediawiki.db):${CL}"
echo -e "${TAB}${YW}Database Name: ${GN}${DB_NAME}${CL}"
echo -e "${TAB}${YW}Database User: ${GN}${DB_USER}${CL}"
echo -e "${TAB}${YW}Database Pass: ${GN}${DB_PASS}${CL}"
echo -e "${TAB}${YW}Database Host: ${GN}localhost${CL}"
echo -e "${TAB}${YW}Database Type: ${GN}PostgreSQL${CL}"
echo -e "\n${INFO}${YW}Complete the installation by visiting:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://\${IP}/mw-config/index.php${CL}\n"
echo -e "${INFO}${YW}Version installed: ${GN}${RELEASE}${CL}"
echo -e "${INFO}${YW}Redis is configured and running on localhost:6379${CL}\n"
