#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: Community
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://www.mediawiki.org/

# App Default Values
APP="MediaWiki"
var_tags="wiki;documentation"
var_cpu="2"
var_ram="2048"
var_disk="8"
var_os="debian"
var_version="12"
var_unprivileged="1"

# App Output & Base Settings
header_info "$APP"
base_settings
echo_default

# Core
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -d /var/www/mediawiki ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  RELEASE=$(curl -s https://www.mediawiki.org/wiki/Download | grep -oP 'MediaWiki \K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  msg_info "Updating ${APP} to ${RELEASE}"
  cd /var/www/mediawiki
  wget -q https://releases.wikimedia.org/mediawiki/${RELEASE%.*}/mediawiki-${RELEASE}.tar.gz
  tar -xzf mediawiki-${RELEASE}.tar.gz --strip-components=1
  rm mediawiki-${RELEASE}.tar.gz
  chown -R www-data:www-data /var/www/mediawiki
  msg_ok "Updated ${APP} to ${RELEASE}"
  msg_info "Updating System"
  apt-get update &>/dev/null
  apt-get -y upgrade &>/dev/null
  msg_ok "Updated System"
  msg_ok "Update Successful"
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}${CL}"
