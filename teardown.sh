#!/usr/bin/env bash
# d-cloud — teardown script
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

[[ ! -f "docker-compose.yml" ]] && error "Run this script from the d-cloud directory."

echo ""
info "Stopping d-cloud..."

if [[ -f ".cloudflared.pid" ]]; then
  kill_tunnel
  success "Stopped Cloudflare Tunnel"
fi

echo ""
echo -e "${YELLOW}Do you want to remove all Nextcloud data (database + config)?${NC}"
echo -e "  ${BOLD}y${NC} — Remove everything (fresh start next time)"
echo -e "  ${BOLD}N${NC} — Keep data (containers stop, data preserved)"
echo ""
read -rp "Remove data? [y/N]: " REMOVE_DATA

if [[ "$REMOVE_DATA" =~ ^[Yy]$ ]]; then
  DISK_PATH=$(grep '^DISK_PATH=' .env 2>/dev/null | cut -d= -f2)

  info "Removing containers and volumes..."
  docker compose down -v --remove-orphans
  rm -f .env
  success "Containers, volumes, and .env removed"

  if [[ -n "$DISK_PATH" && -d "$DISK_PATH" ]]; then
    echo ""
    echo -e "${YELLOW}Also wipe disk storage at: ${BOLD}${DISK_PATH}${NC}${YELLOW}?${NC}"
    echo -e "  ${BOLD}y${NC} — Delete all files in disk path (use for a completely fresh start)"
    echo -e "  ${BOLD}N${NC} — Keep disk files"
    echo ""
    read -rp "Wipe disk? [y/N]: " WIPE_DISK
    if [[ "$WIPE_DISK" =~ ^[Yy]$ ]]; then
      info "Wiping disk storage..."
      rm -rf "${DISK_PATH:?}"/* "${DISK_PATH}"/.[!.]* 2>/dev/null || true
      success "Disk storage wiped: $DISK_PATH"
    else
      warn "Disk storage kept: $DISK_PATH"
    fi
  fi
else
  info "Stopping containers (data preserved)..."
  docker compose down --remove-orphans
  success "Containers stopped. Run 'docker compose up -d' to start again."
fi

echo ""
success "d-cloud stopped."
echo ""
