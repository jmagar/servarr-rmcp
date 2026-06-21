---
name: tautulli
description: This skill should be used when the user asks about Plex watch statistics, current streams, who is watching Plex, active sessions, playback history, most-watched content, user activity, library stats, stream analytics, or anything related to Tautulli monitoring and analytics.
---

# Tautulli — Plex Analytics (via rustarr)

Monitor and analyze Plex Media Server usage through Tautulli. Tautulli is the
**Stats** capability in rustarr, exposing curated `activity` / `history` /
`users` / `libraries` commands plus confirm-gated maintenance writes on top of
Tautulli's `/api/v2` query API (Tautulli dispatches by `?cmd=...`).

## Access model — try in this order

rustarr exposes every service three ways. Prefer the highest tier available:

1. **MCP tool (preferred)** — `mcp__rustarr__tautulli(action="…", …)`. Works
   whenever the rustarr MCP server is connected; credentials live server-side.
2. **rustarr CLI (fallback)** — `rustarr tautulli <verb> [flags]`. Use when the
   MCP server isn't connected but the `rustarr` binary is available (the plugin
   bundles it at `bin/rustarr`; it may also be on `PATH`). It talks to the
   upstreams directly using the same configured credentials.
3. **Direct API (last resort)** — `./scripts/tautulli-api.sh <cmd>`. Bundled curl
   wrapper that hits Tautulli's `/api/v2` directly, reading creds from
   `~/.rustarr/.env` (written by the plugin's `rustarr setup plugin-hook`) or the
   legacy `~/.config/lab-arrs/config.env`. Use only when neither rustarr surface
   is reachable.

**Writes are gated.** Reads (`activity`, `history`, `users`, `libraries`) are
unrestricted. The maintenance writes (`refresh-libraries`, `refresh-users`,
`delete-image-cache`) mutate Tautulli state and need `confirm=true` (MCP) /
`--confirm` (CLI); without it the call is rejected and nothing is changed.

## Operations

| Intent | MCP (preferred) | CLI (fallback) | Direct API (last resort) |
|---|---|---|---|
| Current activity / streams | `action="stats_activity"` | `rustarr tautulli activity` | `./scripts/tautulli-api.sh activity` |
| Watch history | `action="stats_history"` (opts: `start`, `length`, `user`) | `rustarr tautulli history [--start N --length N --user U]` | `./scripts/tautulli-api.sh history [--user U --limit N]` |
| Users (plays per user) | `action="stats_users"` | `rustarr tautulli users` | `./scripts/tautulli-api.sh user-stats` |
| Libraries (sections + counts) | `action="stats_libraries"` | `rustarr tautulli libraries` | `./scripts/tautulli-api.sh libraries` |
| Library section detail | (no curated command) | — | `./scripts/tautulli-api.sh library-stats --section-id N` |
| Home / dashboard stats | (no curated command) | — | `./scripts/tautulli-api.sh home-stats [--days N]` |
| Refresh library inventory | `action="stats_refresh_libraries", confirm=true` | `rustarr tautulli refresh-libraries --confirm` | `api_get /api/v2?cmd=refresh_libraries_list` |
| Refresh user inventory | `action="stats_refresh_users", confirm=true` | `rustarr tautulli refresh-users --confirm` | `api_get /api/v2?cmd=refresh_users_list` |
| Clear image cache | `action="stats_delete_image_cache", confirm=true` | `rustarr tautulli delete-image-cache --confirm` | `api_get /api/v2?cmd=delete_image_cache` |

`api_get <path>` above is shorthand for `mcp__rustarr__tautulli(action="api_get",
path="<path>")` / `rustarr tautulli get --path "<path>"` — the generic passthrough
used where no curated command exists. `api_get` requires `rustarr:write` scope.
Useful raw reads: `/api/v2?cmd=get_activity`, `/api/v2?cmd=get_history&length=20`,
`/api/v2?cmd=get_home_stats`.

## Examples

### Preferred (MCP)

```text
# Who is watching right now
mcp__rustarr__tautulli(action="stats_activity")

# Recent watch history, paged, optionally per-user
mcp__rustarr__tautulli(action="stats_history", length=25)
mcp__rustarr__tautulli(action="stats_history", user="john", start=0, length=50)

# Users and libraries
mcp__rustarr__tautulli(action="stats_users")
mcp__rustarr__tautulli(action="stats_libraries")

# Maintenance writes (mutate Tautulli state — need confirm)
mcp__rustarr__tautulli(action="stats_refresh_libraries", confirm=true)
mcp__rustarr__tautulli(action="stats_delete_image_cache", confirm=true)
```

### Fallback (CLI)

```bash
rustarr tautulli activity
rustarr tautulli history --start 0 --length 25 --user john
rustarr tautulli users
rustarr tautulli libraries
rustarr tautulli refresh-libraries --confirm      # without --confirm = rejected
rustarr tautulli delete-image-cache --confirm
```

### Last resort (direct API script)

```bash
./scripts/tautulli-api.sh activity                # active streams
./scripts/tautulli-api.sh history --user john --days 7
./scripts/tautulli-api.sh user-stats --sort-by plays --limit 10
./scripts/tautulli-api.sh libraries               # all sections
./scripts/tautulli-api.sh library-stats --section-id 1
./scripts/tautulli-api.sh home-stats --days 30    # dashboard overview
```

## Workflow

When the user asks about Plex analytics:

1. **"Who's watching right now?"** → `stats_activity` (CLI `activity`). Returns the
   stream count plus per-stream user, title, state, and progress.
2. **"Show me recent watch history"** → `stats_history` (CLI `history`); narrow with
   `length` for page size and `user` to filter by username, `start` to page.
3. **"How much has each user watched?"** → `stats_users` (CLI `users`) for
   per-user play counts.
4. **"What libraries / sections exist?"** → `stats_libraries` (CLI `libraries`) for
   section id, name, type, and item counts.
5. **"Tautulli's data looks stale"** → `stats_refresh_libraries` /
   `stats_refresh_users` with `confirm=true` to re-sync its Plex inventory.

For history, confirm whether the user wants a specific person (`user`) or a larger
page (`length`) before paging — the defaults return a modest recent window.

## Notes

- Tautulli uses the `/api/v2` query API; every command is a `?cmd=...` call, and
  the curated commands and the script both target it.
- Reads (`stats_activity`, `stats_history`, `stats_users`, `stats_libraries`) are
  GET-only and safe for monitoring.
- The three maintenance commands mutate Tautulli's own state (its cached Plex
  inventory and image cache) — they are confirm-gated; a no-confirm call is
  rejected and nothing is changed.
- History depends on Tautulli's configured retention; some stats need enough
  accumulated data to be meaningful.
- This skill complements the `plex` skill: Plex serves real-time server state,
  Tautulli serves historical analytics and trends.

## Reference

For the direct-API layer and deeper endpoint detail:

- **[API Endpoints](./references/api-endpoints.md)** — full endpoint reference
- **[Quick Reference](./references/quick-reference.md)** — copy-paste examples
- **[Troubleshooting](./references/troubleshooting.md)** — auth/connection/errors
- [Tautulli API docs](https://github.com/Tautulli/Tautulli/wiki/Tautulli-API-Reference)
