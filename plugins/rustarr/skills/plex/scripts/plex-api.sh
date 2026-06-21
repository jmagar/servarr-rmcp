#!/bin/bash
# Plex Media Server API helper script
# Usage: plex-api.sh <command> [args...]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# LAST-RESORT direct-API path. Prefer the rustarr MCP tool (`mcp__rustarr__plex`)
# or the `rustarr plex` CLI when available (see SKILL.md). Creds come from
# rustarr's materialized env (~/.rustarr/.env, written by `rustarr setup
# plugin-hook`), then the legacy arrs config.env. RUSTARR_PLEX_* are aliases.
for _envf in "${RUSTARR_HOME:-$HOME/.rustarr}/.env" "${XDG_CONFIG_HOME:-$HOME/.config}/lab-arrs/config.env"; do
  [[ -f "$_envf" ]] || continue
  set -a
  # shellcheck source=/dev/null
  source "$_envf"
  set +a
done

PLEX_URL="${PLEX_URL:-${RUSTARR_PLEX_URL:-}}"
PLEX_TOKEN="${PLEX_TOKEN:-${RUSTARR_PLEX_TOKEN:-}}"

: "${PLEX_URL:?set RUSTARR_PLEX_URL (rustarr plugin settings) or PLEX_URL}"
: "${PLEX_TOKEN:?set RUSTARR_PLEX_TOKEN (rustarr plugin settings) or PLEX_TOKEN}"

# Map to script's internal variable names
PLEX_URL="${PLEX_URL%/}"  # Remove trailing slash
PLEX_TOKEN="$PLEX_TOKEN"

# Make authenticated API call to Plex
api_call() {
    local method="$1"
    local endpoint="$2"
    shift 2

    curl -sS -X "$method" \
        -H "Accept: application/json" \
        -H "X-Plex-Token: $PLEX_TOKEN" \
        "$@" \
        "${PLEX_URL}${endpoint}"
}

usage() {
    cat <<EOF
Plex Media Server API CLI

Usage: $(basename "$0") <command> [options]

Commands:
  info                           Server information and capabilities
  identity                       Server identity details

  libraries                      List all library sections
  library <section-id> [--limit N] [--offset O]
                                Browse library contents
  recent [--limit N]            Recently added media (default: 20)
  ondeck [--limit N]            Continue watching list (default: 10)

  search <query> [--limit N]    Search across all libraries
  metadata <rating-key>         Get metadata for specific item
  children <rating-key>         Get children of item (e.g., seasons)

  sessions                       Currently playing sessions
  clients                        List connected clients/players

  playlists                      List all playlists
  accounts                       List user accounts (admin only, read-only)
  prefs                          Server preferences (admin only, read-only)

  refresh <section-id>          Refresh library section (admin-only scan)

Examples:
  $(basename "$0") libraries
  $(basename "$0") library 1 --limit 50
  $(basename "$0") search "Inception"
  $(basename "$0") recent --limit 10
  $(basename "$0") sessions
  $(basename "$0") refresh 1
EOF
}

cmd_info() {
    api_call GET "/"
}

cmd_identity() {
    api_call GET "/identity"
}

cmd_libraries() {
    api_call GET "/library/sections"
}

cmd_library() {
    local section_id="$1"; shift
    local limit="" offset=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --limit|-l) limit="$2"; shift 2 ;;
            --offset|-o) offset="$2"; shift 2 ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
        esac
    done

    local params=()
    [[ -n "$limit" ]] && params+=("X-Plex-Container-Size=$limit")
    [[ -n "$offset" ]] && params+=("X-Plex-Container-Start=$offset")

    local query=""
    if [[ ${#params[@]} -gt 0 ]]; then
        query="&$(IFS='&'; echo "${params[*]}")"
    fi

    api_call GET "/library/sections/${section_id}/all${query}"
}

cmd_recent() {
    local limit="20"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --limit|-l) limit="$2"; shift 2 ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
        esac
    done

    api_call GET "/library/recentlyAdded?X-Plex-Container-Size=$limit"
}

cmd_ondeck() {
    local limit="10"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --limit|-l) limit="$2"; shift 2 ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
        esac
    done

    api_call GET "/library/onDeck?X-Plex-Container-Size=$limit"
}

cmd_search() {
    local query="$1"; shift
    local limit=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --limit|-l) limit="$2"; shift 2 ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
        esac
    done

    # URL encode the query
    query=$(echo -n "$query" | jq -sRr @uri)

    local params="query=$query"
    [[ -n "$limit" ]] && params+="&limit=$limit"

    api_call GET "/search?$params"
}

cmd_metadata() {
    local rating_key="$1"
    api_call GET "/library/metadata/$rating_key"
}

cmd_children() {
    local rating_key="$1"
    api_call GET "/library/metadata/$rating_key/children"
}

cmd_sessions() {
    api_call GET "/status/sessions"
}

cmd_clients() {
    api_call GET "/clients"
}

cmd_playlists() {
    api_call GET "/playlists"
}

cmd_accounts() {
    api_call GET "/accounts"
}

cmd_prefs() {
    api_call GET "/:/prefs"
}

cmd_refresh() {
    local section_id="$1"
    api_call GET "/library/sections/${section_id}/refresh"
    echo '{"status": "ok", "message": "Library refresh initiated"}'
}

# Main dispatch
case "${1:-}" in
    info) shift; cmd_info "$@" ;;
    identity) shift; cmd_identity "$@" ;;
    libraries) shift; cmd_libraries "$@" ;;
    library) shift; cmd_library "$@" ;;
    recent) shift; cmd_recent "$@" ;;
    ondeck) shift; cmd_ondeck "$@" ;;
    search) shift; cmd_search "$@" ;;
    metadata) shift; cmd_metadata "$@" ;;
    children) shift; cmd_children "$@" ;;
    sessions) shift; cmd_sessions "$@" ;;
    clients) shift; cmd_clients "$@" ;;
    playlists) shift; cmd_playlists "$@" ;;
    accounts) shift; cmd_accounts "$@" ;;
    prefs) shift; cmd_prefs "$@" ;;
    refresh) shift; cmd_refresh "$@" ;;
    -h|--help|help|"") usage ;;
    *) echo "Unknown command: $1" >&2; usage; exit 1 ;;
esac
