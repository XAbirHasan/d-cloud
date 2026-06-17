#!/usr/bin/env bash
# d-cloud — start/restart services script
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

TUNNEL_OVERRIDE=""

usage() {
cat <<EOF

${BOLD}d-cloud${NC} — start/restart services

${BOLD}Usage:${NC}
  ./d-cloud.sh start [options]

${BOLD}Options:${NC}
  --tunnel <type>   Start/restart with tunnel mode: tailscale, cloudflare, or both
                    If provided, this updates .env and becomes the new default
  -h, --help        Show this help message

${BOLD}Examples:${NC}
  ./d-cloud.sh start
  ./d-cloud.sh start --tunnel cloudflare
  ./d-cloud.sh start --tunnel both

EOF
  exit 0
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tunnel)
        TUNNEL_OVERRIDE="$2"
        shift 2
        ;;
      -h|--help)
        usage
        ;;
      *)
        error "Unknown argument: $1\n  Run ./d-cloud.sh start --help for usage."
        ;;
    esac
  done
}

save_tunnel_to_env() {
  local tunnel="$1"
  awk -v tunnel="$tunnel" '
    BEGIN { updated = 0 }
    /^TUNNEL=/ {
      print "TUNNEL=" tunnel
      updated = 1
      next
    }
    { print }
    END {
      if (updated == 0) print "TUNNEL=" tunnel
    }
  ' .env > .env.tmp && mv .env.tmp .env
}

parse_args "$@"

[[ ! -f "docker-compose.yml" ]] && error "Run this script from the d-cloud directory."
[[ ! -f ".env" ]] && error "Not configured yet. Run ./d-cloud.sh setup --disk <path> first."

PORT=$(grep '^PORT=' .env | cut -d= -f2)
TUNNEL=$(grep '^TUNNEL=' .env | cut -d= -f2)

if [[ -n "$TUNNEL_OVERRIDE" ]]; then
  validate_tunnel_type "$TUNNEL_OVERRIDE"
  save_tunnel_to_env "$TUNNEL_OVERRIDE"
  TUNNEL="$TUNNEL_OVERRIDE"
  success "Tunnel mode updated to: ${TUNNEL}"
fi

validate_tunnel_type "$TUNNEL"
check_tunnel_dependencies "$TUNNEL"

info "Starting/restarting d-cloud services..."
docker compose up -d
success "d-cloud services are running."

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
