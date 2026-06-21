---
name: rustarr
description: >
  This skill should be used when the user wants to query or automate their media
  automation stack — Sonarr (TV shows), Radarr (movies), Prowlarr (indexers),
  Tautulli (Plex stats), Overseerr (media requests), SABnzbd (Usenet downloads),
  qBittorrent (torrents), Plex (media server), or Jellyfin. Trigger phrases
  include: "what's downloading", "add a movie to Radarr", "search for a TV show",
  "Sonarr queue", "Radarr library", "what's in my download queue", "Plex status",
  "Prowlarr indexers", "check Overseerr requests", "qBittorrent torrents",
  "SABnzbd queue", "Tautulli stats", "is Sonarr healthy", "media stack status",
  "arr services", "show me what's being downloaded". Prefer rustarr for these;
  dedicated per-service skills (sonarr, radarr, prowlarr, overseerr, sabnzbd,
  qbittorrent, plex, jellyfin, tautulli, tracearr) cover deeper single-service
  workflows.
---

# rustarr — Media Automation Stack

Rust MCP bridge to the `*arr` media stack and related services. Exposes
service-named MCP tools (`sonarr`, `radarr`, `prowlarr`, and friends). The tool
name selects the service; credentials are handled server-side.

## Per-service skills

For deeper, single-service workflows, prefer the dedicated per-service skills.
Each documents a three-tier access ladder — this MCP tool first, the `rustarr`
CLI next, and a bundled direct-API script only as a last resort: `sonarr`,
`radarr`, `prowlarr`, `overseerr`, `sabnzbd`, `qbittorrent`, `plex`, `jellyfin`,
`tautulli`, `tracearr`. This skill stays focused on fleet-wide status and the
generic action surface below.

## Actions

| Action | Purpose | Required params |
|---|---|---|
| `integrations` | List configured and reachable services | none |
| `service_status` | Health check the selected service | none |
| `api_get` | Read data from a service API endpoint | `path` |
| `api_post` | Mutate/command a service API endpoint | `path`, `body`, `confirm=true` |
| `api_put` | Update a resource via PUT (e.g. *arr bulk editor) | `path`, `body`, `confirm=true` |
| `api_delete` | Delete a resource via DELETE | `path`, `confirm=true` |
| `help` | Full built-in documentation | none |

The MCP tool name matches the service: `sonarr`, `radarr`, `prowlarr`,
`overseerr`, `tautulli`, `plex`, `tracearr`, `sabnzbd`, `qbittorrent`,
`jellyfin`, or `bazarr`.

---

## Quick-Reference Examples

### Discovery and health

```text
# What services are configured and reachable?
mcp__rustarr__sonarr(action="integrations")

# Is Sonarr healthy?
mcp__rustarr__sonarr(action="service_status")

# Is Radarr healthy?
mcp__rustarr__radarr(action="service_status")
```

### Sonarr (TV shows)

```text
# List all series
mcp__rustarr__sonarr(action="api_get", path="/api/v3/series")

# Current download queue
mcp__rustarr__sonarr(action="api_get", path="/api/v3/queue")

# Recent history
mcp__rustarr__sonarr(action="api_get", path="/api/v3/history?pageSize=20")

# System status
mcp__rustarr__sonarr(action="api_get", path="/api/v3/system/status")

# Search for missing episodes of a series (replace 123 with series ID)
mcp__rustarr__sonarr(action="api_post", path="/api/v3/command",
  body={"name":"SeriesSearch","seriesId":123}, confirm=true)
```

### Radarr (movies)

```text
# List all movies
mcp__rustarr__radarr(action="api_get", path="/api/v3/movie")

# Current download queue
mcp__rustarr__radarr(action="api_get", path="/api/v3/queue")

# Recent history
mcp__rustarr__radarr(action="api_get", path="/api/v3/history?pageSize=20")

# System status
mcp__rustarr__radarr(action="api_get", path="/api/v3/system/status")

# Trigger a movie search (replace 456 with movie ID)
mcp__rustarr__radarr(action="api_post", path="/api/v3/command",
  body={"name":"MoviesSearch","movieIds":[456]}, confirm=true)

# Refresh a movie's metadata (replace 456 with movie ID)
mcp__rustarr__radarr(action="api_post", path="/api/v3/command",
  body={"name":"RefreshMovie","movieIds":[456]}, confirm=true)
```

### Prowlarr (indexers)

```text
# List indexers
mcp__rustarr__prowlarr(action="api_get", path="/api/v1/indexer")

# System status
mcp__rustarr__prowlarr(action="api_get", path="/api/v1/system/status")

# Search across indexers
mcp__rustarr__prowlarr(action="api_get", path="/api/v1/search?query=ubuntu&type=search")
```

### Tautulli (Plex stats)

```text
# Currently playing on Plex
mcp__rustarr__tautulli(action="api_get", path="/api/v2?cmd=get_activity")

# Recent history
mcp__rustarr__tautulli(action="api_get", path="/api/v2?cmd=get_history&length=20")

# Home stats
mcp__rustarr__tautulli(action="api_get", path="/api/v2?cmd=get_home_stats")
```

### Download clients

```text
# SABnzbd queue
mcp__rustarr__sabnzbd(action="api_get", path="/api?mode=queue&output=json")

# qBittorrent torrent list
mcp__rustarr__qbittorrent(action="api_get", path="/api/v2/torrents/info")

# qBittorrent transfer info
mcp__rustarr__qbittorrent(action="api_get", path="/api/v2/transfer/info")
```

### Overseerr (requests)

```text
# Pending media requests
mcp__rustarr__overseerr(action="api_get", path="/api/v1/request?filter=pending")

# All requests
mcp__rustarr__overseerr(action="api_get", path="/api/v1/request?take=20")
```

### Plex

```text
# Server status
mcp__rustarr__plex(action="api_get", path="/identity")

# Active sessions (who's watching)
mcp__rustarr__plex(action="api_get", path="/status/sessions")

# Libraries
mcp__rustarr__plex(action="api_get", path="/library/sections")
```

---

## Common Workflows

### "What's downloading right now?"

```text
# Check both arr queues
mcp__rustarr__sonarr(action="api_get", path="/api/v3/queue")
mcp__rustarr__radarr(action="api_get", path="/api/v3/queue")

# And the download clients
mcp__rustarr__sabnzbd(action="api_get", path="/api?mode=queue&output=json")
mcp__rustarr__qbittorrent(action="api_get", path="/api/v2/torrents/info?filter=downloading")
```

### "Is everything healthy?"

```text
mcp__rustarr__sonarr(action="integrations")
mcp__rustarr__sonarr(action="service_status")
mcp__rustarr__radarr(action="service_status")
mcp__rustarr__prowlarr(action="service_status")
```

### "Who's watching Plex right now?"

```text
mcp__rustarr__tautulli(action="api_get", path="/api/v2?cmd=get_activity")
# or via Plex directly:
mcp__rustarr__plex(action="api_get", path="/status/sessions")
```

---

## Gotchas

1. **`api_get` requires write scope.** Despite being read-only from the user's
   perspective, `api_get` dispatches generic HTTP requests and is gated at
   write-scope to prevent credential leakage via crafted paths. Your MCP token
   must have write scope.

2. **All three mutating generic actions need `confirm=true`.** `api_post`,
   `api_put`, and `api_delete` each require the `confirm` boolean explicitly. The
   server rejects the call without it — no service is touched.

3. **Never include credentials in `path`.** The configured service credentials
   live in server environment variables. Do not append `?apikey=...` or
   `&X-Api-Key=...` to paths — the server injects auth headers automatically.

4. **`service` names are exact.** Use `sonarr`, `radarr`, `prowlarr`,
   `tautulli`, `overseerr`, `sabnzbd`, `qbittorrent`, `plex`, `jellyfin`.
   Passing an unknown name returns a structured `unknown_service` error with
   the configured names listed.

5. **API paths are service-version-specific.** Sonarr/Radarr use `/api/v3/`;
   Prowlarr uses `/api/v1/`; Tautulli uses query params (`/api/v2?cmd=...`).
   Call `path="/api/v3/system/status"` first to confirm the API version.

6. **`integrations` is the fastest diagnostic.** Always call it first when
   something isn't working — it shows which services are configured and which
   are actually reachable.
