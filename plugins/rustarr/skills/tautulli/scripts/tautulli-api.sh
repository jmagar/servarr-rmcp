#!/bin/bash
# Tautulli API helper script
# Usage: tautulli-api.sh <command> [args...]

set -euo pipefail

# LAST-RESORT direct-API path. Prefer the rustarr MCP tool (`mcp__rustarr__tautulli`)
# or the `rustarr tautulli` CLI when available (see SKILL.md). Creds come from
# rustarr's materialized env (~/.rustarr/.env, written by `rustarr setup
# plugin-hook`), then the legacy arrs config.env. RUSTARR_TAUTULLI_* are aliases.
for _envf in "${RUSTARR_HOME:-$HOME/.rustarr}/.env" "${XDG_CONFIG_HOME:-$HOME/.config}/lab-arrs/config.env"; do
  [[ -f "$_envf" ]] || continue
  set -a
  # shellcheck source=/dev/null
  source "$_envf"
  set +a
done

TAUTULLI_URL="${TAUTULLI_URL:-${RUSTARR_TAUTULLI_URL:-}}"
TAUTULLI_API_KEY="${TAUTULLI_API_KEY:-${RUSTARR_TAUTULLI_API_KEY:-}}"

: "${TAUTULLI_URL:?set RUSTARR_TAUTULLI_URL (rustarr plugin settings) or TAUTULLI_URL}"
: "${TAUTULLI_API_KEY:?set RUSTARR_TAUTULLI_API_KEY (rustarr plugin settings) or TAUTULLI_API_KEY}"

# Remove trailing slash from URL
TAUTULLI_URL="${TAUTULLI_URL%/}"

urlencode() {
    jq -nr --arg v "$1" '$v|@uri'
}

require_value() {
    local option="$1"
    local value="${2:-}"
    if [[ -z "$value" || "$value" == --* ]]; then
        echo "ERROR: $option requires a value" >&2
        exit 2
    fi
}

# Make authenticated API call to Tautulli
api_call() {
    local cmd="$1"
    shift

    # Build query parameters
    local params
    params="apikey=$(urlencode "$TAUTULLI_API_KEY")&cmd=$(urlencode "$cmd")&out_type=json"

    # Add additional parameters
    local param key value
    for param in "$@"; do
        key="${param%%=*}"
        value="${param#*=}"
        params+="&$(urlencode "$key")=$(urlencode "$value")"
    done

    # Make request
    curl -sS -X GET "${TAUTULLI_URL}/api/v2?${params}"
}

usage() {
    cat <<EOF
Tautulli Analytics API CLI

Usage: $(basename "$0") <command> [options]

Commands:
  server-info                    Server version and information

  activity [--details]          Current activity and active streams

  history [options]             Playback history
    --user <username>              Filter by user
    --section-id <id>              Filter by library section
    --media-type <type>            Filter by media type (movie, episode, track, etc.)
    --days <n>                     Last N days
    --limit <n>                    Maximum results (default: 25)
    --search <query>               Search in titles

  user-stats [options]          User statistics
    --user <username>              Specific user
    --sort-by <metric>             Sort by plays, duration, last_seen
    --limit <n>                    Maximum results
    --days <n>                     Last N days

  libraries                     List all library sections
  library-stats --section-id <id>
                                Library statistics for section

  popular [options]             Most popular content
    --section-id <id>              Filter by library section
    --media-type <type>            Filter by media type
    --days <n>                     Timeframe (default: 30)
    --limit <n>                    Maximum results (default: 10)

  recent [options]              Recently added media
    --section-id <id>              Filter by library section
    --media-type <type>            Filter by media type
    --days <n>                     Last N days
    --limit <n>                    Maximum results (default: 25)

  home-stats [--days <n>]       Homepage dashboard statistics

  plays-by-stream [--days <n>]  Plays by stream type (direct/transcode)
  plays-by-platform [--days <n>]
                                Plays by platform/device
  plays-by-date [--days <n>]    Plays by date
  plays-by-hour [--days <n>]    Plays by hour of day
  plays-by-day [--days <n>]     Plays by day of week

  concurrent-streams [options]  Concurrent stream history
    --days <n>                     Timeframe
    --peak                         Show peak concurrent streams

  metadata [options]            Media metadata
    --rating-key <key>             Plex rating key
    --guid <guid>                  Plex GUID

Examples:
  $(basename "$0") activity
  $(basename "$0") history --user "john" --days 7
  $(basename "$0") user-stats --sort-by plays --limit 10
  $(basename "$0") popular --media-type movie --days 30
  $(basename "$0") recent --section-id 1 --limit 50
  $(basename "$0") plays-by-hour --days 7
EOF
}

cmd_server_info() {
    api_call "get_server_info"
}

cmd_activity() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --details) shift ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
        esac
    done

    api_call "get_activity"
}

cmd_history() {
    local params=()
    local limit="25"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --user) require_value "$1" "${2:-}"; params+=("user=$2"); shift 2 ;;
            --section-id) require_value "$1" "${2:-}"; params+=("section_id=$2"); shift 2 ;;
            --media-type) require_value "$1" "${2:-}"; params+=("media_type=$2"); shift 2 ;;
            --days)
                require_value "$1" "${2:-}"
                local start_date
                start_date=$(date -d "$2 days ago" +%s)
                params+=("start_date=$start_date")
                shift 2
                ;;
            --limit) require_value "$1" "${2:-}"; limit="$2"; shift 2 ;;
            --search) require_value "$1" "${2:-}"; params+=("search=$2"); shift 2 ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
        esac
    done

    params+=("length=$limit")

    api_call "get_history" "${params[@]}"
}

cmd_user_stats() {
    local params=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --user) require_value "$1" "${2:-}"; params+=("user=$2"); shift 2 ;;
            --sort-by) require_value "$1" "${2:-}"; params+=("order_column=$2"); shift 2 ;;
            --limit) require_value "$1" "${2:-}"; params+=("length=$2"); shift 2 ;;
            --days)
                require_value "$1" "${2:-}"
                local start_date
                start_date=$(date -d "$2 days ago" +%s)
                params+=("start_date=$start_date")
                shift 2
                ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
        esac
    done

    if [[ ${#params[@]} -gt 0 ]]; then
        api_call "get_user_stats" "${params[@]}"
    else
        api_call "get_users"
    fi
}

cmd_libraries() {
    api_call "get_libraries"
}

cmd_library_stats() {
    local section_id=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --section-id) require_value "$1" "${2:-}"; section_id="$2"; shift 2 ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
        esac
    done

    if [[ -z "$section_id" ]]; then
        echo "ERROR: --section-id required" >&2
        exit 1
    fi

    api_call "get_library" "section_id=$section_id"
}

cmd_popular() {
    local params=()
    local days="30"
    local limit="10"
    local media_type="movie"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --section-id) require_value "$1" "${2:-}"; params+=("section_id=$2"); shift 2 ;;
            --media-type) require_value "$1" "${2:-}"; media_type="$2"; shift 2 ;;
            --days) require_value "$1" "${2:-}"; days="$2"; shift 2 ;;
            --limit) require_value "$1" "${2:-}"; limit="$2"; shift 2 ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
        esac
    done

    params+=("time_range=$days")
    params+=("length=$limit")

    case "$media_type" in
        movie|movies) api_call "get_home_stats" "stat_id=popular_movies" "${params[@]}" ;;
        episode|show|shows|tv) api_call "get_home_stats" "stat_id=popular_tv" "${params[@]}" ;;
        track|artist|music) api_call "get_home_stats" "stat_id=popular_music" "${params[@]}" ;;
        *) echo "ERROR: unsupported --media-type for popular: $media_type" >&2; exit 2 ;;
    esac
}

cmd_recent() {
    local params=()
    local limit="25"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --section-id) require_value "$1" "${2:-}"; params+=("section_id=$2"); shift 2 ;;
            --media-type) require_value "$1" "${2:-}"; params+=("media_type=$2"); shift 2 ;;
            --days)
                require_value "$1" "${2:-}"
                local start
                start=$(date -d "$2 days ago" +%s)
                params+=("start=$start")
                shift 2
                ;;
            --limit) require_value "$1" "${2:-}"; limit="$2"; shift 2 ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
        esac
    done

    params+=("count=$limit")

    api_call "get_recently_added" "${params[@]}"
}

cmd_home_stats() {
    local days="30"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --days) require_value "$1" "${2:-}"; days="$2"; shift 2 ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
        esac
    done

    api_call "get_home_stats" "time_range=$days"
}

cmd_plays_by_stream() {
    local days="30"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --days) require_value "$1" "${2:-}"; days="$2"; shift 2 ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
        esac
    done

    api_call "get_plays_by_stream_type" "time_range=$days" "y_axis=plays"
}

cmd_plays_by_platform() {
    local days="30"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --days) require_value "$1" "${2:-}"; days="$2"; shift 2 ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
        esac
    done

    api_call "get_plays_by_top_10_platforms" "time_range=$days" "y_axis=plays"
}

cmd_plays_by_date() {
    local days="30"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --days) require_value "$1" "${2:-}"; days="$2"; shift 2 ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
        esac
    done

    api_call "get_plays_by_date" "time_range=$days" "y_axis=plays"
}

cmd_plays_by_hour() {
    local days="30"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --days) require_value "$1" "${2:-}"; days="$2"; shift 2 ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
        esac
    done

    api_call "get_plays_by_hourofday" "time_range=$days" "y_axis=plays"
}

cmd_plays_by_day() {
    local days="30"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --days) require_value "$1" "${2:-}"; days="$2"; shift 2 ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
        esac
    done

    api_call "get_plays_by_dayofweek" "time_range=$days" "y_axis=plays"
}

cmd_concurrent_streams() {
    local days="30"
    local peak=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --days) require_value "$1" "${2:-}"; days="$2"; shift 2 ;;
            --peak) peak="1"; shift ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
        esac
    done

    if [[ -n "$peak" ]]; then
        api_call "get_plays_per_month" "time_range=$days" "y_axis=concurrent"
    else
        api_call "get_concurrent_streams_by_stream_type" "time_range=$days"
    fi
}

cmd_metadata() {
    local rating_key=""
    local guid=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --rating-key) require_value "$1" "${2:-}"; rating_key="$2"; shift 2 ;;
            --guid) require_value "$1" "${2:-}"; guid="$2"; shift 2 ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
        esac
    done

    if [[ -n "$rating_key" ]]; then
        api_call "get_metadata" "rating_key=$rating_key"
    elif [[ -n "$guid" ]]; then
        api_call "get_metadata" "guid=$guid"
    else
        echo "ERROR: --rating-key or --guid required" >&2
        exit 1
    fi
}

# Main dispatch
case "${1:-}" in
    server-info) shift; cmd_server_info "$@" ;;
    activity) shift; cmd_activity "$@" ;;
    history) shift; cmd_history "$@" ;;
    user-stats) shift; cmd_user_stats "$@" ;;
    libraries) shift; cmd_libraries "$@" ;;
    library-stats) shift; cmd_library_stats "$@" ;;
    popular) shift; cmd_popular "$@" ;;
    recent) shift; cmd_recent "$@" ;;
    home-stats) shift; cmd_home_stats "$@" ;;
    plays-by-stream) shift; cmd_plays_by_stream "$@" ;;
    plays-by-platform) shift; cmd_plays_by_platform "$@" ;;
    plays-by-date) shift; cmd_plays_by_date "$@" ;;
    plays-by-hour) shift; cmd_plays_by_hour "$@" ;;
    plays-by-day) shift; cmd_plays_by_day "$@" ;;
    concurrent-streams) shift; cmd_concurrent_streams "$@" ;;
    metadata) shift; cmd_metadata "$@" ;;
    -h|--help|help|"") usage ;;
    *) echo "Unknown command: $1" >&2; usage; exit 1 ;;
esac
