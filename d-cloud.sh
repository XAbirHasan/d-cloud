#!/usr/bin/env bash
# d-cloud — single entrypoint for common operations
set -euo pipefail

usage() {
cat <<EOF

Usage:
  ./d-cloud.sh <command> [options]

Commands:
  setup      Initial setup (alias: init)
  start      Start/restart services (aliases: up, restart)
  stop       Stop services without deleting data (alias: down)
  status     Show config + runtime status (alias: ps)
  reset      Stop services with optional data deletion (aliases: teardown, destroy)
  help       Show this help

Examples:
  ./d-cloud.sh setup --disk /path/to/disk --tunnel both
  ./d-cloud.sh start --tunnel cloudflare
  ./d-cloud.sh status
  ./d-cloud.sh stop
  ./d-cloud.sh reset

EOF
}

[[ ! -f "docker-compose.yml" ]] && {
  echo "Run this script from the d-cloud directory." >&2
  exit 1
}

CMD="${1:-help}"
if [[ $# -gt 0 ]]; then
  shift
fi

case "$CMD" in
  setup|init)
    ./setup.sh "$@"
    ;;
  start|up|restart)
    ./restart.sh "$@"
    ;;
  stop|down)
    ./stop.sh "$@"
    ;;
  status|ps)
    ./status.sh "$@"
    ;;
  reset|teardown|destroy)
    ./teardown.sh "$@"
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo "Unknown command: $CMD" >&2
    usage
    exit 1
    ;;
esac
