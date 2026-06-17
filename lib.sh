#!/usr/bin/env bash
# Shared helpers — sourced by setup.sh, restart.sh, stop.sh, status.sh, teardown.sh

RED='\033[0;31m' 
GREEN='\033[0;32m' 
YELLOW='\033[1;33m' 
BLUE='\033[0;34m' 
BOLD='\033[1m' 
NC='\033[0m'

info()    { echo -e "${BLUE}[d-cloud]${NC} $*"; }
success() { echo -e "${GREEN}✓${NC} $*"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $*"; }
error()   { echo -e "${RED}✗ ERROR:${NC} $*" >&2; exit 1; }

require_command() {
  local cmd="$1"
  local msg="$2"
  command -v "$cmd" &>/dev/null || error "$msg"
}

validate_tunnel_type() {
  local tunnel="$1"
  case "$tunnel" in
    tailscale|cloudflare|both) ;;
    *) error "--tunnel must be 'tailscale', 'cloudflare', or 'both', got: $tunnel" ;;
  esac
}

check_tunnel_dependencies() {
  local tunnel="$1"

  validate_tunnel_type "$tunnel"

  if [[ "$tunnel" == "tailscale" || "$tunnel" == "both" ]]; then
    require_command tailscale "Tailscale is not installed. Install it from: https://tailscale.com/download"
    tailscale status &>/dev/null || error "Tailscale is not running or not logged in. Run: sudo tailscale up"
  fi

  if [[ "$tunnel" == "cloudflare" || "$tunnel" == "both" ]]; then
    require_command cloudflared "cloudflared is not installed. Install it from: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/"
  fi
}

# Kill any running cloudflared tunnel and clean up pid/log files
kill_tunnel() {
  if [[ -f ".cloudflared.pid" ]]; then
    kill "$(cat .cloudflared.pid)" 2>/dev/null || true
    rm -f .cloudflared.pid .cloudflared.log
  fi
}

# Start a cloudflared quick tunnel and wait for the URL.
# Usage: start_tunnel <port>
# Sets CF_URL and CF_DOMAIN on success.
start_tunnel() {
  local port="$1"
  CF_URL="" CF_DOMAIN=""

  kill_tunnel
  info "Starting Cloudflare Tunnel..."
  nohup cloudflared tunnel --url "http://localhost:${port}" --no-autoupdate --protocol http2 \
    > .cloudflared.log 2>&1 &
  echo $! > .cloudflared.pid

  printf "[d-cloud] Waiting for tunnel URL"
  local attempts=0
  while [[ $attempts -lt 60 ]]; do
    CF_URL=$(grep -o 'https://[a-zA-Z0-9-]*\.trycloudflare\.com' .cloudflared.log 2>/dev/null | head -1 || true)
    [[ -n "$CF_URL" ]] && break
    attempts=$((attempts + 1))
    printf "."
    sleep 1
  done
  echo ""

  if [[ -n "$CF_URL" ]]; then
    CF_DOMAIN="${CF_URL#https://}"
  else
    warn "Could not get Cloudflare Tunnel URL. Check: cat .cloudflared.log"
  fi
}
