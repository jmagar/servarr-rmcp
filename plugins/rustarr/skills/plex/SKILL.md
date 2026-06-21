---
name: plex
description: >-
  This skill should be used when the user wants to interact with their Plex
  Media Server. Triggers include "check Plex", "search Plex", "what's on Plex",
  "what's playing on Plex", "who's watching", "Plex sessions", "active
  streams", "Plex library", "browse movies", "browse TV shows", "recently
  added", "on deck", "continue watching", "Plex status", or any mention of Plex
  Media Server.
---

# Plex — Media Server (via rustarr)

Browse libraries, search media, and monitor active streaming sessions on Plex.
Plex is a **MediaServer** service in rustarr (so is Jellyfin), exposing curated
`sessions` / `libraries` / `search` / `scan` commands on top of the Plex API.

## Access model — try in this order

rustarr exposes every service three ways. Prefer the highest tier available:

1. **MCP tool (preferred)** — `mcp__rustarr__plex(action="…", …)`. Works whenever
   the rustarr MCP server is connected; credentials live server-side.
2. **rustarr CLI (fallback)** — `rustarr plex <verb> [flags]`. Use when the MCP
   server isn't connected but the `rustarr` binary is available (the plugin
   bundles it at `bin/rustarr`; it may also be on `PATH`). It talks to the
   upstream directly using the same configured credentials.
3. **Direct API (last resort)** — `./scripts/plex-api.sh <cmd>`. Bundled curl
   wrapper that hits the Plex API directly, reading creds from `~/.rustarr/.env`
   (written by the plugin's `rustarr setup plugin-hook`) or the legacy
   `~/.config/lab-arrs/config.env`. Use only when neither rustarr surface is
   reachable.

**Writes are gated.** The one mutating action — `media_scan` — needs
`confirm=true` (MCP) / `--confirm` (CLI); without it the call is rejected and
nothing is changed. Reads (sessions, libraries, search, identity) are unrestricted.

> Library note: `media_scan` on Plex **requires a section id** for `library`
> (list sections first via `libraries`). On Jellyfin the same command refreshes
> the whole server and ignores `library` — don't carry a Plex section id over.

## Operations

| Intent | MCP (preferred) | CLI (fallback) | Direct API (last resort) |
|---|---|---|---|
| Active sessions | `action="media_sessions"` | `rustarr plex sessions` | `./scripts/plex-api.sh sessions` (or `api_get /status/sessions`) |
| List libraries | `action="media_libraries"` | `rustarr plex libraries` | `./scripts/plex-api.sh libraries` (or `api_get /library/sections`) |
| Search media | `action="media_search", query="Inception"` | `rustarr plex search --query "Inception"` | `./scripts/plex-api.sh search "Inception"` |
| Server identity / status | `action="api_get", path="/identity"` | `rustarr plex get --path "/identity"` | `./scripts/plex-api.sh identity` (or `api_get /identity`) |
| Scan a library | `action="media_scan", library="1", confirm=true` | `rustarr plex scan --library 1 --confirm` | `./scripts/plex-api.sh refresh 1` |
| Browse a section | `action="api_get", path="/library/sections/1/all"` | `rustarr plex get --path "/library/sections/1/all"` | `./scripts/plex-api.sh library 1` |
| Recently added | `action="api_get", path="/library/recentlyAdded"` | `rustarr plex get --path "/library/recentlyAdded"` | `./scripts/plex-api.sh recent` |
| On deck (continue watching) | `action="api_get", path="/library/onDeck"` | `rustarr plex get --path "/library/onDeck"` | `./scripts/plex-api.sh ondeck` |

`api_get <path>` above is shorthand for `mcp__rustarr__plex(action="api_get",
path="<path>")` / `rustarr plex get --path "<path>"` — the generic passthrough
used where no curated command exists. `api_get` requires `rustarr:write` scope.

## Examples

### Preferred (MCP)

```text
# Who's watching right now, and what libraries exist
mcp__rustarr__plex(action="media_sessions")
mcp__rustarr__plex(action="media_libraries")

# Search the server
mcp__rustarr__plex(action="media_search", query="Inception")

# Trigger a scan of section 1 (writes need confirm=true; rejected without it)
mcp__rustarr__plex(action="media_scan", library="1", confirm=true)

# Anything without a curated command goes through api_get
mcp__rustarr__plex(action="api_get", path="/identity")
```

### Fallback (CLI)

```bash
rustarr plex sessions
rustarr plex libraries
rustarr plex search --query "Inception"
rustarr plex scan --library 1 --confirm
rustarr plex get --path "/identity"
```

### Last resort (direct API script)

```bash
./scripts/plex-api.sh sessions             # currently playing
./scripts/plex-api.sh libraries            # section keys + types
./scripts/plex-api.sh search "Inception"   # search across libraries
./scripts/plex-api.sh library 1 --limit 50 # browse a section
./scripts/plex-api.sh identity             # server identity
./scripts/plex-api.sh refresh 1            # scan section 1 (admin-only)
```

## Workflow

When the user asks about Plex:

1. **"Who's watching right now?"** → `media_sessions` (or the script's `sessions`).
2. **"What's on Plex?"** → `media_libraries` for the section overview, then browse
   a section via `api_get /library/sections/<id>/all` (script: `library <id>`).
3. **"Search for Inception"** → `media_search query="Inception"`.
4. **"Rescan my Movies library"** → list sections via `media_libraries` to get the
   **section id**, confirm with the user, then `media_scan library="<id>"
   confirm=true`. Plex requires the section id; a server-wide scan isn't offered.

Always list sections first (`media_libraries`) to get the correct section keys —
they vary per server.

## Notes

- Plex authenticates with an `X-Plex-Token` (`X-Plex-Token` header). The token is
  scoped to the account — keep it secure.
- Reachable passthrough paths on the Plex kind are `/identity`, `/library`,
  `/status`, and `/servers` (e.g. `/status/sessions`, `/library/sections`).
- Section keys (1, 2, 3...) vary by server setup — list them first.
- `media_scan` starts an async server-side scan (Plex requires a section id) and
  returns immediately; it does not poll for completion.
- Append `Accept: application/json` is handled for you by the curated commands and
  the script; raw Plex calls default to XML otherwise.

## Reference

For the direct-API layer and deeper endpoint detail:

- **[API Endpoints](./references/api-endpoints.md)** — complete endpoint reference with parameters
- **[Quick Reference](./references/quick-reference.md)** — common operations with copy-paste examples
- **[Troubleshooting](./references/troubleshooting.md)** — authentication, connection, and error solutions
- [Plex Media Server API](https://www.plexopedia.com/plex-media-server/api/) and the [Plex Web App](https://app.plex.tv/)
