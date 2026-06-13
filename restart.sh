#!/usr/bin/env bash
# d-cloud — restart script
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

[[ ! -f "docker-compose.yml" ]] && error "Run this script from the d-cloud directory."
[[ ! -f ".env" ]] && error "Not configured yet. Run ./setup.sh first."

info "Restarting d-cloud..."
docker compose restart
success "d-cloud restarted."

PORT=$(grep '^PORT=' .env | cut -d= -f2)
TUNNEL=$(grep '^TUNNEL=' .env | cut -d= -f2)

echo ""
echo -e "  ${BOLD}Local access:${NC} http://localhost:${PORT:-7070}"

if [[ "$TUNNEL" == "cloudflare" ]]; then
  start_tunnel "${PORT:-7070}"
  if [[ -n "$CF_URL" ]]; then
    echo -e "  ${BOLD}Remote access:${NC} ${CF_URL}"
    docker compose exec -T nextcloud php occ config:system:set trusted_domains 2 \
      --value="$CF_DOMAIN" 2>/dev/null || true
  fi
fi

echo ""
