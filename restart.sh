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

if [[ "$TUNNEL" == "tailscale" || "$TUNNEL" == "both" ]]; then
  TS_IP=$(tailscale ip -4 2>/dev/null || true)
  [[ -n "$TS_IP" ]] && echo -e "  ${BOLD}Remote access:${NC} http://${TS_IP}:${PORT:-7070}  (Tailscale)"
fi

if [[ "$TUNNEL" == "cloudflare" || "$TUNNEL" == "both" ]]; then
  CF_DOMAIN_INDEX=2
  [[ "$TUNNEL" == "both" ]] && CF_DOMAIN_INDEX=3
  start_tunnel "${PORT:-7070}"
  if [[ -n "$CF_URL" ]]; then
    echo -e "  ${BOLD}Remote access:${NC} ${CF_URL}  (Cloudflare)"
    docker compose exec -T nextcloud php occ config:system:set trusted_domains ${CF_DOMAIN_INDEX} \
      --value="$CF_DOMAIN" 2>/dev/null || true
  fi
fi

echo ""
