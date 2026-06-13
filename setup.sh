#!/usr/bin/env bash
# d-cloud — setup script
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

# User configurable
DISK_PATH=""
TUNNEL="tailscale"
PORT="7070"
ADMIN_USER="admin"

# Internal state
INTERACTIVE=false
TS_IP=""
CF_URL=""
CF_DOMAIN=""
DB_PASSWORD=""
ADMIN_PASSWORD=""
TRUSTED_DOMAINS=""
NC_READY=false
LOGS_PID=""


usage() {
cat <<EOF

${BOLD}d-cloud${NC} — Share your disk as private cloud storage

${BOLD}Usage:${NC}
  ./setup.sh --disk <path> [options]

${BOLD}Options:${NC}
  --disk <path>     Path to the disk or folder to use as storage (required)
  --tunnel <type>   Remote access method: tailscale (default) or cloudflare
  --port <port>     Local port for Nextcloud (default: 7070)
  --admin <user>    Admin username (default: admin)
  --interactive     Stream live logs during startup, stop watching when ready
  -h, --help        Show this help message

${BOLD}Examples:${NC}
  ./setup.sh --disk /mnt/my-drive
  ./setup.sh --disk /mnt/my-drive --tunnel cloudflare
  ./setup.sh --disk ~/storage --admin alice --port 9090
  ./setup.sh --disk /mnt/my-drive --interactive

EOF
  exit 0
}

require_command() {
  local cmd="$1"
  local msg="$2"
  command -v "$cmd" &>/dev/null || error "$msg"
}

generate_password() {
  openssl rand -hex 32
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --disk)
        DISK_PATH="$2"
        shift 2
        ;;
      --tunnel)
        TUNNEL="$2"
        shift 2
        ;;
      --port)
        PORT="$2"
        shift 2
        ;;
      --admin)
        ADMIN_USER="$2"
        shift 2
        ;;
      --interactive)
        INTERACTIVE=true
        shift
        ;;
      -h|--help)
        usage
        ;;
      *)
        error "Unknown argument: $1\n  Run ./setup.sh --help for usage."
        ;;
    esac
  done
}


validate_port() {
  if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [[ "$PORT" -lt 1 || "$PORT" -gt 65535 ]]; then
    error "--port must be a valid port number (1-65535), got: $PORT"
  fi
}

validate_args() {
  [[ -n "$DISK_PATH" ]] \
    || error "--disk is required.\n  Example: ./setup.sh --disk /mnt/my-drive"

  [[ -d "$DISK_PATH" ]] \
    || error "Disk path does not exist or is not a directory: $DISK_PATH"

  case "$TUNNEL" in
    tailscale|cloudflare) ;;
    *) error "--tunnel must be 'tailscale' or 'cloudflare', got: $TUNNEL" ;;
  esac

  validate_port

  # Resolve to absolute path (portable, no realpath needed)
  DISK_PATH=$(cd "$DISK_PATH" && pwd)
}

check_existing_install() {
  if [[ -f ".env" ]]; then
    warn "d-cloud appears to be already configured (.env exists)."
    warn "To start fresh, run: ./teardown.sh"
    exit 1
  fi
}

check_tunnel_dependencies() {
  case "$TUNNEL" in
    tailscale)
      require_command tailscale \
        "Tailscale is not installed.\n  Install it from: https://tailscale.com/download"
      tailscale status &>/dev/null \
        || error "Tailscale is not running or not logged in.\n  Run: sudo tailscale up"
      ;;
    cloudflare)
      require_command cloudflared \
        "cloudflared is not installed.\n  Install it from: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/"
      ;;
  esac
}

check_dependencies() {
  echo ""
  info "Checking dependencies..."

  require_command docker \
    "Docker is not installed.\n  Install it from: https://docs.docker.com/get-docker/"

  docker info &>/dev/null \
    || error "Docker daemon is not running.\n  Start Docker Desktop, or run: sudo systemctl start docker"

  docker compose version &>/dev/null \
    || error "Docker Compose v2 is not available.\n  Update Docker: https://docs.docker.com/compose/install/"

  require_command curl "curl is not installed. Install it via your system package manager."
  require_command openssl "openssl is not installed. Install it via your system package manager."

  check_tunnel_dependencies

  success "All dependencies found"
}

generate_credentials() {
  DB_PASSWORD=$(generate_password)
  ADMIN_PASSWORD=$(generate_password)
}

determine_trusted_domains() {
  TRUSTED_DOMAINS="localhost 127.0.0.1"

  [[ "$TUNNEL" != "tailscale" ]] && return

  TS_IP=$(tailscale ip -4 2>/dev/null || true)

  [[ -n "$TS_IP" ]] || {
    warn "Could not detect Tailscale IP. You can add it later via Nextcloud admin settings."
    return
  }

  TRUSTED_DOMAINS="${TRUSTED_DOMAINS} ${TS_IP}"
  success "Tailscale IP detected: ${TS_IP}"
}

write_env() {
  cat > .env <<EOF
# d-cloud configuration — generated on $(date)
# DO NOT commit this file or share it — it contains your credentials

DISK_PATH=${DISK_PATH}
PORT=${PORT}
ADMIN_USER=${ADMIN_USER}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
DB_PASSWORD=${DB_PASSWORD}
TRUSTED_DOMAINS=${TRUSTED_DOMAINS}
TUNNEL=${TUNNEL}
EOF

  success "Credentials generated and saved to .env"
}


prepare_disk() {
  info "Preparing disk path..."
  chmod 777 "$DISK_PATH" 2>/dev/null || sudo chmod 777 "$DISK_PATH" \
    || error "Cannot set permissions on disk path: $DISK_PATH"
  if [[ ! -f "$DISK_PATH/.ncdata" ]]; then
    echo '# Nextcloud data directory' > "$DISK_PATH/.ncdata" \
      || error "Cannot write to disk path: $DISK_PATH"
  fi
  success "Disk path ready"
}

start_containers() {
  echo ""
  info "Pulling Docker images and starting containers (this may take a few minutes)..."
  docker compose up -d --pull always

  if [[ "$INTERACTIVE" == true ]]; then
    info "Streaming logs — press Ctrl+C to stop watching (containers will keep running)..."
    echo ""
    docker compose logs -f nextcloud nginx &
    LOGS_PID=$!
  fi
}

wait_for_nextcloud() {
  echo ""
  info "Waiting for PHP-FPM to start..."
  echo -n "   "

  local attempts=0
  local max_attempts=60  # 5 minutes max

  until curl -sf "http://localhost:${PORT}/status.php" 2>/dev/null | grep -q '"version"'; do
    attempts=$((attempts + 1))
    if [[ $attempts -ge $max_attempts ]]; then
      echo ""
      error "PHP-FPM did not start in time. Check logs: docker compose logs nextcloud"
    fi
    echo -n "."
    sleep 5
  done
  echo ""

  # Stop the log tail before running installer
  if [[ "$INTERACTIVE" == true ]]; then
    kill "$LOGS_PID" 2>/dev/null || true
    wait "$LOGS_PID" 2>/dev/null || true
  fi
}

install_nextcloud() {
  if curl -sf "http://localhost:${PORT}/status.php" 2>/dev/null | grep -q '"installed":false'; then
    info "Running Nextcloud installer..."
    docker compose exec -T nextcloud php occ maintenance:install \
      --database pgsql \
      --database-host db \
      --database-name nextcloud \
      --database-user nextcloud \
      --database-pass "${DB_PASSWORD}" \
      --admin-user "${ADMIN_USER}" \
      --admin-pass "${ADMIN_PASSWORD}" \
      --data-dir /mnt/data \
    && NC_READY=true \
    || error "Nextcloud installation failed. Check logs: docker compose logs nextcloud"
  elif curl -sf "http://localhost:${PORT}/status.php" 2>/dev/null | grep -q '"installed":true'; then
    NC_READY=true
  fi
}

setup_cloudflare() {
  start_tunnel "$PORT"

  [[ -n "$CF_URL" ]] || return

  if [[ "$NC_READY" == true ]]; then
    docker compose exec -T nextcloud php /var/www/html/occ \
      config:system:set trusted_domains 2 --value="$CF_DOMAIN" 2>/dev/null \
      && success "Cloudflare domain registered with Nextcloud" \
      || warn "Could not register Cloudflare domain. Add it manually in Nextcloud admin settings."
  else
    warn "Nextcloud not fully ready — add $CF_DOMAIN manually in Nextcloud admin → Trusted Domains."
  fi

  success "Cloudflare Tunnel active: ${CF_URL}"
}

setup_tunnel() {
  case "$TUNNEL" in
    tailscale)
      # Tailscale is already running system-wide; nothing to start
      success "Tailscale tunnel ready"
      ;;
    cloudflare) setup_cloudflare ;;
  esac
}

print_summary() {
  echo ""
  echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}${BOLD}  d-cloud is ready!${NC}"
  echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "  ${BOLD}Local access:${NC}    http://localhost:${PORT}"

  if [[ "$TUNNEL" == "tailscale" && -n "$TS_IP" ]]; then
    echo -e "  ${BOLD}Remote access:${NC}   http://${TS_IP}:${PORT}  (Tailscale)"
    echo ""
    echo -e "  ${YELLOW}Install Tailscale on your other devices to connect remotely.${NC}"
  elif [[ "$TUNNEL" == "cloudflare" && -n "$CF_URL" ]]; then
    echo -e "  ${BOLD}Remote access:${NC}   ${CF_URL}  (Cloudflare)"
    echo ""
    echo -e "  ${YELLOW}Quick tunnel URL resets on every restart.${NC}"
    echo -e "  ${YELLOW}For a permanent URL, see README → Cloudflare Named Tunnels.${NC}"
  fi

  echo ""
  echo -e "  ${BOLD}Admin username:${NC}  ${ADMIN_USER}"
  echo -e "  ${BOLD}Admin password:${NC}  ${ADMIN_PASSWORD}"
  echo ""
  echo -e "  ${BOLD}Disk path:${NC}       ${DISK_PATH}"
  echo -e "  ${BOLD}Port:${NC}            ${PORT}"
  echo ""
  echo -e "  ${YELLOW}Credentials are saved in .env — do not share this file.${NC}"
  echo -e "  ${YELLOW}To stop:  ./teardown.sh${NC}"
  echo ""
}

main() {
  parse_args "$@"
  validate_args                  # fail fast before touching anything

  check_existing_install         # don't overwrite a running install
  check_dependencies             # verify docker, tunnel binary, etc. are present

  generate_credentials           # random DB + admin passwords, written nowhere yet
  determine_trusted_domains      # detect Tailscale IP now, before containers start
  write_env                      # persist everything to .env for docker compose

  prepare_disk                   # ensure correct permissions on the data directory

  start_containers               # docker compose up; optionally tail logs
  wait_for_nextcloud             # PHP-FPM can take 1-3 min on first boot — poll until ready
  install_nextcloud              # occ maintenance:install only runs if not already installed

  setup_tunnel                   # start cloudflared / register domain with Nextcloud
  print_summary                  # show URLs, credentials, next steps
}

main "$@"
