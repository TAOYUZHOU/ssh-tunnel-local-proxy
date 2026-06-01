#!/usr/bin/env bash
# Run on YOUR LOCAL machine (where Clash / mixed-port proxy is running).
# Forwards local proxy port to a remote host via SSH reverse tunnel (-R).
#
# Usage:
#   cp config.example config.local   # edit REMOTE_HOST / REMOTE_PORT
#   ./tunnel-local.sh
#   ./tunnel-local.sh --background   # run in background (nohup)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/config.local}"

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

# Backward-compatible aliases (older config.local used AUTODL_*)
REMOTE_HOST="${REMOTE_HOST:-${AUTODL_HOST:-}}"
REMOTE_PORT="${REMOTE_PORT:-${AUTODL_PORT:-}}"
REMOTE_USER="${REMOTE_USER:-${AUTODL_USER:-root}}"
LOCAL_PROXY_PORT="${LOCAL_PROXY_PORT:-7890}"
REMOTE_PROXY_PORT="${REMOTE_PROXY_PORT:-7890}"

usage() {
  cat <<EOF
Usage: $0 [--background]

Prerequisites:
  1. Local proxy client listening on 127.0.0.1:${LOCAL_PROXY_PORT}
     (Clash mixed-port, Surge enhanced mode, etc.)
  2. config.local with REMOTE_HOST and REMOTE_PORT

After the tunnel is up, on the REMOTE host run:
  ./proxy-server.sh on
EOF
}

check_local_proxy() {
  if ! (echo >/dev/tcp/127.0.0.1/"$LOCAL_PROXY_PORT") 2>/dev/null; then
    echo "ERROR: Local proxy not listening on 127.0.0.1:${LOCAL_PROXY_PORT}" >&2
    echo "       Start Clash (or your client) first, then retry." >&2
    exit 1
  fi
  echo "OK: Local proxy reachable at 127.0.0.1:${LOCAL_PROXY_PORT}"
}

run_tunnel() {
  local bg="${1:-false}"
  local ssh_cmd=(
    ssh
    -CNg
    -R "${REMOTE_PROXY_PORT}:127.0.0.1:${LOCAL_PROXY_PORT}"
    -o "ServerAliveInterval=30"
    -o "ServerAliveCountMax=3"
    -o "ExitOnForwardFailure=yes"
    -p "$REMOTE_PORT"
    "${REMOTE_USER}@${REMOTE_HOST}"
  )

  echo "Tunnel: remote 127.0.0.1:${REMOTE_PROXY_PORT} -> local 127.0.0.1:${LOCAL_PROXY_PORT}"
  echo "SSH: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PORT}"
  echo ""
  echo "Keep this terminal open (or use --background). On the remote host, run:"
  echo "  ./proxy-server.sh on"
  echo ""

  if [[ "$bg" == "true" ]]; then
    local log_file="${SCRIPT_DIR}/tunnel-local.log"
    nohup "${ssh_cmd[@]}" >>"$log_file" 2>&1 &
    echo "Background tunnel started (pid $!). Log: $log_file"
  else
    exec "${ssh_cmd[@]}"
  fi
}

main() {
  local background=false
  case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    --background) background=true ;;
    "") ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac

  if [[ -z "$REMOTE_HOST" || -z "$REMOTE_PORT" ]]; then
    echo "ERROR: Set REMOTE_HOST and REMOTE_PORT in $CONFIG_FILE" >&2
    exit 1
  fi

  check_local_proxy
  run_tunnel "$background"
}

main "$@"
