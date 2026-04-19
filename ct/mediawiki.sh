#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: Community
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://www.mediawiki.org/

# App Default Values
APP="MediaWiki"
var_tags="${var_tags:-wiki;documentation}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

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
  if [ -z "$RELEASE" ]; then
    msg_error "Failed to detect MediaWiki version"
    exit 1
  fi
  msg_info "Updating ${APP} to ${RELEASE}"
  cd /var/www/mediawiki || exit
  wget -q https://releases.wikimedia.org/mediawiki/${RELEASE%.*}/mediawiki-${RELEASE}.tar.gz
  if [ $? -ne 0 ]; then
    msg_error "Failed to download MediaWiki ${RELEASE}"
    exit 1
  fi
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
echo -e "${INFO}${YW} Access the MediaWiki installer at:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}/mw-config/index.php${CL}"
echo -e "${INFO}${YW} Database credentials are saved in:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}/root/mediawiki.db${CL}"
