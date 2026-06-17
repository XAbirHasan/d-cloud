#!/usr/bin/env bash
# d-cloud — show status and saved configuration
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

[[ ! -f "docker-compose.yml" ]] && error "Run this script from the d-cloud directory."

if [[ ! -f ".env" ]]; then
  warn "d-cloud is not configured yet. Run ./d-cloud.sh setup --disk <path> first."
  exit 0
fi

PORT=$(grep '^PORT=' .env | cut -d= -f2)
TUNNEL=$(grep '^TUNNEL=' .env | cut -d= -f2)
DISK_PATH=$(grep '^DISK_PATH=' .env | cut -d= -f2)
ADMIN_USER=$(grep '^ADMIN_USER=' .env | cut -d= -f2)

PORT=${PORT:-7070}

echo ""
echo -e "${BOLD}d-cloud status${NC}"
echo -e "  ${BOLD}Tunnel mode:${NC} ${TUNNEL:-unknown}"
echo -e "  ${BOLD}Port:${NC} ${PORT}"
echo -e "  ${BOLD}Disk path:${NC} ${DISK_PATH:-unknown}"
echo -e "  ${BOLD}Admin user:${NC} ${ADMIN_USER:-unknown}"

echo ""
echo -e "${BOLD}Access:${NC}"
echo -e "  Local: http://localhost:${PORT}"

if [[ "${TUNNEL:-}" == "tailscale" || "${TUNNEL:-}" == "both" ]]; then
  if command -v tailscale &>/dev/null && tailscale status &>/dev/null; then
    TS_IP=$(tailscale ip -4 2>/dev/null || true)
    [[ -n "$TS_IP" ]] && echo -e "  Tailscale: http://${TS_IP}:${PORT}"
  else
    echo "  Tailscale: unavailable (tailscale not running)"
  fi
fi

if [[ "${TUNNEL:-}" == "cloudflare" || "${TUNNEL:-}" == "both" ]]; then
  CF_URL=""
  if [[ -f ".cloudflared.log" ]]; then
    CF_URL=$(grep -o 'https://[a-zA-Z0-9-]*\.trycloudflare\.com' .cloudflared.log 2>/dev/null | head -1 || true)
  fi

  if [[ -f ".cloudflared.pid" ]] && kill -0 "$(cat .cloudflared.pid)" 2>/dev/null; then
    if [[ -n "$CF_URL" ]]; then
      echo -e "  Cloudflare: ${CF_URL}"
    else
      echo "  Cloudflare: running (URL not found in log yet)"
    fi
  else
    echo "  Cloudflare: not running"
  fi
fi

if command -v docker &>/dev/null && docker info &>/dev/null; then
  echo ""
  echo -e "${BOLD}Containers:${NC}"
  docker compose ps
else
  echo ""
  warn "Docker daemon is not running, cannot show container status."
fi
