#!/bin/bash
set -euo pipefail

# Sonarr API wrapper — LAST-RESORT direct-API path.
#
# Prefer the rustarr MCP tool (`mcp__rustarr__sonarr`) or the `rustarr sonarr`
# CLI when available; this curl wrapper is the fallback when neither is (see
# SKILL.md). Credentials are read from rustarr's materialized env
# (~/.rustarr/.env, written by `rustarr setup plugin-hook`), falling back to the
# legacy arrs config.env. RUSTARR_SONARR_* names are accepted as aliases.
for _envf in "${RUSTARR_HOME:-$HOME/.rustarr}/.env" "${XDG_CONFIG_HOME:-$HOME/.config}/lab-arrs/config.env"; do
  [[ -f "$_envf" ]] || continue
  set -a
  # shellcheck source=/dev/null
  source "$_envf"
  set +a
done

SONARR_URL="${SONARR_URL:-${RUSTARR_SONARR_URL:-}}"
SONARR_API_KEY="${SONARR_API_KEY:-${RUSTARR_SONARR_API_KEY:-}}"

: "${SONARR_URL:?set RUSTARR_SONARR_URL (rustarr plugin settings) or SONARR_URL}"
: "${SONARR_API_KEY:?set RUSTARR_SONARR_API_KEY (rustarr plugin settings) or SONARR_API_KEY}"

SONARR_URL="${SONARR_URL%/}"

# Optional quality profile (with default fallback)
DEFAULT_QUALITY_PROFILE="${SONARR_DEFAULT_QUALITY_PROFILE:-1}"

API="$SONARR_URL/api/v3"
AUTH="X-Api-Key: $SONARR_API_KEY"

usage() {
  cat <<'EOF'
Usage: sonarr.sh <command> [args]

Commands:
  search <query>                         Search for TV shows
  search-json <query>                    Search for TV shows and return JSON
  exists <tvdbId>                        Check if a show is in the library
  config                                 Show root folders and quality profiles
  add <tvdbId> [profileId] [--no-search] Add a show; searches by default
  remove <tvdbId> [--delete-files]       Remove a show from the library
EOF
}

require_arg() {
  local value="${1:-}"
  local name="$2"
  if [[ -z "$value" ]]; then
    echo "ERROR: missing required argument: $name" >&2
    usage >&2
    exit 2
  fi
}

urlencode() {
  jq -nr --arg v "$1" '$v|@uri'
}

cmd="${1:-}"
if [[ -z "$cmd" ]]; then
  usage
  exit 0
fi
shift || true

case "$cmd" in
  search)
    query="${1:-}"
    require_arg "$query" "query"
    curl -fsS -H "$AUTH" "$API/series/lookup?term=$(urlencode "$query")" | jq -r '
      to_entries | .[:10] | .[] | 
      "\(.key + 1). \(.value.title) (\(.value.year)) - TVDB \(.value.tvdbId) - https://thetvdb.com/dereferrer/series/\(.value.tvdbId)"
    '
    ;;
    
  search-json)
    query="${1:-}"
    require_arg "$query" "query"
    curl -fsS -H "$AUTH" "$API/series/lookup?term=$(urlencode "$query")"
    ;;
    
  exists)
    tvdbId="${1:-}"
    require_arg "$tvdbId" "tvdbId"
    result=$(curl -fsS -H "$AUTH" "$API/series?tvdbId=$(urlencode "$tvdbId")")
    if [ "$result" = "[]" ]; then
      echo "not_found"
    else
      echo "exists"
      echo "$result" | jq -r '.[0] | "ID: \(.id), Title: \(.title), Seasons: \(.statistics.seasonCount)"'
    fi
    ;;
    
  config)
    echo "=== Root Folders ==="
    curl -fsS -H "$AUTH" "$API/rootfolder" | jq -r '.[] | "\(.id): \(.path)"'
    echo ""
    echo "=== Quality Profiles ==="
    curl -fsS -H "$AUTH" "$API/qualityprofile" | jq -r '.[] | "\(.id): \(.name)"'
    ;;
    
  add)
    tvdbId="${1:-}"
    require_arg "$tvdbId" "tvdbId"
    qualityProfileId="${2:-}"
    searchFlag="true"
    
    # Check for --no-search flag
    for arg in "$@"; do
      if [ "$arg" = "--no-search" ]; then
        searchFlag="false"
      fi
    done
    
    # Get series details from lookup
    series=$(curl -fsS -H "$AUTH" "$API/series/lookup?term=tvdb:$(urlencode "$tvdbId")" | jq '.[0]')
    
    if [ "$series" = "null" ] || [ -z "$series" ]; then
      echo "ERROR: Show not found with TVDB ID: $tvdbId"
      exit 1
    fi
    
    # Get default root folder
    rootFolder=$(curl -fsS -H "$AUTH" "$API/rootfolder" | jq -r '.[0].path')
    
    # Use provided quality profile ID, config default, or first available
    if [ -z "$qualityProfileId" ] || [ "$qualityProfileId" = "--no-search" ]; then
      if [ -n "$DEFAULT_QUALITY_PROFILE" ]; then
        qualityProfile="$DEFAULT_QUALITY_PROFILE"
      else
        qualityProfile=$(curl -fsS -H "$AUTH" "$API/qualityprofile" | jq -r '.[0].id')
      fi
    else
      qualityProfile="$qualityProfileId"
    fi
    
    # Build add request
    addRequest=$(echo "$series" | jq --arg rf "$rootFolder" --argjson qp "$qualityProfile" --argjson search "$searchFlag" '
      . + {
        rootFolderPath: $rf,
        qualityProfileId: $qp,
        monitored: true,
        seasonFolder: true,
        addOptions: {
          monitor: "all",
          searchForMissingEpisodes: $search,
          searchForCutoffUnmetEpisodes: false
        }
      }
    ')
    
    result=$(curl -fsS -X POST -H "$AUTH" -H "Content-Type: application/json" -d "$addRequest" "$API/series")
    
    if echo "$result" | jq -e '.id' > /dev/null 2>&1; then
      title=$(echo "$result" | jq -r '.title')
      year=$(echo "$result" | jq -r '.year')
      seasons=$(echo "$result" | jq -r '.statistics.seasonCount // "?"')
      echo "OK: Added: $title ($year) - $seasons seasons"
      if [ "$searchFlag" = "true" ]; then
        echo "Search started"
      fi
    else
      echo "ERROR: Failed to add show"
      echo "$result" | jq -r '.message // .'
    fi
    ;;
    
  remove)
    tvdbId="${1:-}"
    require_arg "$tvdbId" "tvdbId"
    deleteFiles="false"
    if [ "${2:-}" = "--delete-files" ]; then
      deleteFiles="true"
    fi
    
    # Get series ID from library
    series=$(curl -fsS -H "$AUTH" "$API/series?tvdbId=$(urlencode "$tvdbId")")
    
    if [ "$series" = "[]" ]; then
      echo "ERROR: Show not found in library"
      exit 1
    fi
    
    seriesId=$(echo "$series" | jq -r '.[0].id')
    title=$(echo "$series" | jq -r '.[0].title')
    year=$(echo "$series" | jq -r '.[0].year')
    
    curl -fsS -X DELETE -H "$AUTH" "$API/series/$seriesId?deleteFiles=$deleteFiles" > /dev/null
    
    if [ "$deleteFiles" = "true" ]; then
      echo "Removed: $title ($year) + deleted files"
    else
      echo "Removed: $title ($year) (files kept)"
    fi
    ;;
    
  *)
    echo "Unknown command: $cmd" >&2
    usage >&2
    exit 2
    ;;
esac
