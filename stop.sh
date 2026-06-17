#!/usr/bin/env bash
# d-cloud — stop services without deleting data
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

[[ ! -f "docker-compose.yml" ]] && error "Run this script from the d-cloud directory."

info "Stopping d-cloud services..."

if [[ -f ".cloudflared.pid" ]]; then
  kill_tunnel
  success "Stopped Cloudflare Tunnel"
fi

docker compose down --remove-orphans
success "Containers stopped. Data is preserved."
