#!/usr/bin/env bash
# Tracearr API helper.
# Usage: tracearr-api.sh <command> [args...]

set -euo pipefail

load_config() {
  # LAST-RESORT direct-API path. Prefer the rustarr MCP tool (`mcp__rustarr__tracearr`)
  # or the `rustarr tracearr` CLI when available (see SKILL.md). Read creds from
  # rustarr's materialized env (~/.rustarr/.env), the legacy arrs config.env, and
  # ~/.lab/.env. RUSTARR_TRACEARR_* names are accepted as aliases.
  local rustarr_env="${RUSTARR_HOME:-$HOME/.rustarr}/.env"
  local config="${TRACEARR_ENV_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/lab-arrs/config.env}"
  local _envf
  for _envf in "$rustarr_env" "$HOME/.lab/.env" "$config"; do
    [[ -f "$_envf" ]] || continue
    set -a
    # shellcheck source=/dev/null
    source "$_envf"
    set +a
  done

  TRACEARR_URL="${TRACEARR_URL:-${RUSTARR_TRACEARR_URL:-}}"
  TRACEARR_API_KEY="${TRACEARR_API_KEY:-${RUSTARR_TRACEARR_TOKEN:-${RUSTARR_TRACEARR_API_KEY:-}}}"

  : "${TRACEARR_URL:?set RUSTARR_TRACEARR_URL (rustarr plugin settings) or TRACEARR_URL}"
  TRACEARR_URL="${TRACEARR_URL%/}"
}

api() {
  local method="$1"
  local endpoint="$2"
  shift 2
  local args=()
  if [[ -n "${TRACEARR_API_KEY:-}" ]]; then
    args+=(-H "Authorization: Bearer ${TRACEARR_API_KEY}")
  fi
  curl -sS -X "$method" -H "Accept: application/json" "${args[@]}" "$@" "${TRACEARR_URL}${endpoint}"
}

usage() {
  cat <<'EOF'
Usage: tracearr-api.sh <command> [args...]

Commands:
  health                       Probe Tracearr base URL
  api-docs                     Fetch Swagger UI/API docs page
  get <path>                   GET an arbitrary API path
  streams                      GET /api/streams
  servers                      GET /api/servers
  alerts                       GET /api/alerts

Environment:
  TRACEARR_URL from lab-arrs config or ~/.lab/.env.
  TRACEARR_API_KEY is optional and sent as a bearer token when present.
EOF
}

cmd="${1:-help}"
shift || true
case "$cmd" in
  help|-h|--help) usage; exit 0 ;;
esac
load_config

case "$cmd" in
  health) curl -sS -o /dev/null -w 'HTTP %{http_code}\n' "${TRACEARR_URL}/" ;;
  api-docs) curl -sS "${TRACEARR_URL}/api-docs" ;;
  get)
    path="${1:?API path required}"
    [[ "$path" == /* ]] || path="/$path"
    api GET "$path"
    ;;
  streams) api GET "/api/streams" ;;
  servers) api GET "/api/servers" ;;
  alerts) api GET "/api/alerts" ;;
  *) usage >&2; exit 2 ;;
esac
