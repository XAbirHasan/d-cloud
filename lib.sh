#!/usr/bin/env bash
# Shared helpers — sourced by setup.sh, restart.sh, teardown.sh

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
