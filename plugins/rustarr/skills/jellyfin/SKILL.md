---
name: jellyfin
description: "This skill should be used when the user asks about Jellyfin media server. Triggers include: \"check Jellyfin\", \"Jellyfin library\", \"who's watching on Jellyfin\", \"active Jellyfin sessions\", \"add a Jellyfin user\", \"Jellyfin metadata\", \"Jellyfin transcoding\", \"Jellyfin health\", \"Jellyfin scheduled tasks\", \"Jellyfin plugins\", or any mention of Jellyfin media server management."
---

# Jellyfin — Media Server (via rustarr)

Browse libraries, search items, and monitor active streaming sessions on
Jellyfin. Jellyfin is a **MediaServer** service in rustarr (so is Plex), exposing
curated `sessions` / `libraries` / `search` / `scan` commands on top of the
Jellyfin API.

## Access model — try in this order

rustarr exposes every service three ways. Prefer the highest tier available:

1. **MCP tool (preferred)** — `mcp__rustarr__jellyfin(action="…", …)`. Works
   whenever the rustarr MCP server is connected; credentials live server-side.
2. **rustarr CLI (fallback)** — `rustarr jellyfin <verb> [flags]`. Use when the MCP
   server isn't connected but the `rustarr` binary is available (the plugin
   bundles it at `bin/rustarr`; it may also be on `PATH`). It talks to the
   upstream directly using the same configured credentials.
3. **Direct API (last resort)** — `./scripts/jellyfin-api.sh <cmd>`. Bundled curl
   wrapper that hits the Jellyfin API directly, reading creds from
   `~/.rustarr/.env` (written by the plugin's `rustarr setup plugin-hook`), the
   legacy `~/.config/lab-arrs/config.env`, or `~/.lab/.env`. Use only when neither
   rustarr surface is reachable.

**Writes are gated.** The one mutating action — `media_scan` — needs
`confirm=true` (MCP) / `--confirm` (CLI); without it the call is rejected and
nothing is changed. Reads (sessions, libraries, search, system info) are unrestricted.

> Library note: `media_scan` on Jellyfin refreshes the **whole server** and
> ignores any `library` value. On Plex the same command requires a section id —
> don't carry a Plex section id over to Jellyfin.

## Operations

| Intent | MCP (preferred) | CLI (fallback) | Direct API (last resort) |
|---|---|---|---|
| Active sessions | `action="media_sessions"` | `rustarr jellyfin sessions` | `./scripts/jellyfin-api.sh sessions` (or `api_get /Sessions`) |
| List libraries | `action="media_libraries"` | `rustarr jellyfin libraries` | `./scripts/jellyfin-api.sh libraries` (or `api_get /Library/VirtualFolders`) |
| Search media | `action="media_search", query="Inception"` | `rustarr jellyfin search --query "Inception"` | `./scripts/jellyfin-api.sh search "Inception"` |
| Server info / status | `action="api_get", path="/System/Info"` | `rustarr jellyfin get --path "/System/Info"` | `./scripts/jellyfin-api.sh info` (or `api_get /System/Info`) |
| Scan (server-wide) | `action="media_scan", confirm=true` | `rustarr jellyfin scan --confirm` | `./scripts/jellyfin-api.sh refresh <item-id>` |
| List users | `action="api_get", path="/Users"` | `rustarr jellyfin get --path "/Users"` | `./scripts/jellyfin-api.sh users` |
| Item details | `action="api_get", path="/Items/<id>"` | `rustarr jellyfin get --path "/Items/<id>"` | `./scripts/jellyfin-api.sh item <id>` |
| Scheduled tasks | `action="api_get", path="/ScheduledTasks"` | `rustarr jellyfin get --path "/ScheduledTasks"` | `./scripts/jellyfin-api.sh tasks` |

`api_get <path>` above is shorthand for `mcp__rustarr__jellyfin(action="api_get",
path="<path>")` / `rustarr jellyfin get --path "<path>"` — the generic passthrough
used where no curated command exists. `api_get` requires `rustarr:write` scope.

## Examples

### Preferred (MCP)

```text
# Who's watching right now, and what libraries exist
mcp__rustarr__jellyfin(action="media_sessions")
mcp__rustarr__jellyfin(action="media_libraries")

# Search the server
mcp__rustarr__jellyfin(action="media_search", query="Inception")

# Trigger a server-wide scan (writes need confirm=true; library is ignored)
mcp__rustarr__jellyfin(action="media_scan", confirm=true)

# Anything without a curated command goes through api_get
mcp__rustarr__jellyfin(action="api_get", path="/System/Info")
```

### Fallback (CLI)

```bash
rustarr jellyfin sessions
rustarr jellyfin libraries
rustarr jellyfin search --query "Inception"
rustarr jellyfin scan --confirm                # server-wide; --library is ignored
rustarr jellyfin get --path "/System/Info"
```

### Last resort (direct API script)

```bash
./scripts/jellyfin-api.sh sessions             # active sessions
./scripts/jellyfin-api.sh libraries            # library virtual folders
./scripts/jellyfin-api.sh search "Inception"   # search items
./scripts/jellyfin-api.sh info                 # server info
./scripts/jellyfin-api.sh users                # list users
./scripts/jellyfin-api.sh item <id>            # item details
./scripts/jellyfin-api.sh refresh <item-id>    # refresh metadata for an item (write)
```

## Workflow

When the user asks about Jellyfin:

1. **"Who's watching right now?"** → `media_sessions` (or the script's `sessions`).
2. **"What's on Jellyfin?"** → `media_libraries` for the virtual-folder overview.
3. **"Search for Inception"** → `media_search query="Inception"`.
4. **"Rescan my libraries"** → `media_scan confirm=true`. Jellyfin refreshes the
   whole server, so `library` is ignored; for a single item instead, use the
   script's `refresh <item-id>` last-resort path.

For read-only checks (server info, users, sessions, scheduled tasks), reach for
`media_*` first and fall back to `api_get` for anything not curated.

## Notes

- Jellyfin authenticates with an `X-Emby-Token` (the API key passed in the
  `X-Emby-Token` header; the `Authorization: MediaBrowser Token="<token>"` form is
  equivalent on some client paths). The token is privileged — keep it secure.
- Reachable passthrough roots on the Jellyfin kind are `/System`, `/Items`,
  `/Users`, `/Library`, and `/Sessions` (e.g. `/Sessions`,
  `/Library/VirtualFolders`, `/System/Info`).
- `media_scan` is server-wide and ignores `library`; it starts an async refresh
  and returns immediately without polling for completion.
- Treat delete, metadata rewrite, library rescan, and user-permission changes as
  writes — confirm the intended object ids before executing them.

## Reference

For the full Jellyfin REST surface and parameter detail, see the upstream API
docs:

- [Jellyfin API documentation](https://api.jellyfin.org/)
