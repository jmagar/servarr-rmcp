---
name: sonarr
description: >-
  This skill should be used when the user wants to manage TV shows in Sonarr via
  the rustarr media stack. Triggers include "add a TV show", "add to Sonarr",
  "search Sonarr", "find a series", "remove a show", "delete show", "is [show]
  in my library", "what's airing", "upcoming episodes", "Sonarr queue", "Sonarr
  wanted/missing", "Sonarr health", or any mention of Sonarr / TV-show library
  management.
---

# Sonarr — TV Show Management (via rustarr)

Search, add, monitor, and remove TV shows in Sonarr. Sonarr is an **ArrManager**
service in rustarr (so is Radarr), exposing curated `list` / `search` / `add` /
`delete` style commands on top of the Sonarr `/api/v3` REST API.

## Access model — try in this order

rustarr exposes every service three ways. Prefer the highest tier available:

1. **MCP tool (preferred)** — `mcp__rustarr__sonarr(action="…", …)`. Works
   whenever the rustarr MCP server is connected; credentials live server-side.
2. **rustarr CLI (fallback)** — `rustarr sonarr <verb> [flags]`. Use when the MCP
   server isn't connected but the `rustarr` binary is available (the plugin
   bundles it at `bin/rustarr`; it may also be on `PATH`). It talks to the
   upstreams directly using the same configured credentials.
3. **Direct API (last resort)** — `./scripts/sonarr.sh <cmd>`. Bundled curl
   wrapper that hits Sonarr's `/api/v3` directly, reading creds from
   `~/.rustarr/.env` (written by the plugin's `rustarr setup plugin-hook`) or the
   legacy `~/.config/lab-arrs/config.env`. Use only when neither rustarr surface
   is reachable.

**Writes are gated.** Every mutating action needs `confirm=true` (MCP) /
`--confirm` (CLI); without it you get a dry-run preview. Reads are unrestricted.

> Identifier note: the MCP/CLI `add` takes a **search term** (title) and `delete`
> takes the **Sonarr series id** (from `list`). The direct-API script instead
> uses **TVDB ids** for `add`/`remove`/`exists`. Don't mix them across tiers.

## Operations

| Intent | MCP (preferred) | CLI (fallback) | Direct API (last resort) |
|---|---|---|---|
| List library | `action="list"` (opts: `limit`, `offset`, `fields`) | `rustarr sonarr list` | `api_get /api/v3/series` |
| Wanted / missing | `action="wanted"` | `rustarr sonarr wanted` | `api_get /api/v3/wanted/missing` |
| Download/import queue | `action="queue"` | `rustarr sonarr queue` | `api_get /api/v3/queue` |
| Recent history | `action="history"` | `rustarr sonarr history` | `api_get /api/v3/history` |
| Quality profiles | `action="quality_profiles"` | `rustarr sonarr quality-profiles` | `./scripts/sonarr.sh config` |
| Root folders | `action="rootfolders"` | `rustarr sonarr rootfolders` | `./scripts/sonarr.sh config` |
| Health checks | `action="health"` | `rustarr sonarr health` | `api_get /api/v3/health` |
| Find a show to add | `action="add", term="Breaking Bad"` (no confirm = preview) | `rustarr sonarr add --term "Breaking Bad"` | `./scripts/sonarr.sh search "Breaking Bad"` |
| Check if it exists | (find via `list`/`add` preview) | — | `./scripts/sonarr.sh exists <tvdbId>` |
| Add a show | `action="add", term, quality_profile, root_folder, confirm=true` | `rustarr sonarr add --term "X" --quality-profile "HD-1080p" --root-folder /tv --confirm` | `./scripts/sonarr.sh add <tvdbId> [profileId]` |
| Monitor / unmonitor | `action="monitor"` / `"unmonitor"` (`title` or `ids`, `confirm=true`) | `rustarr sonarr monitor --title "X" --confirm` | — (raw `PUT /api/v3/series/editor`) |
| Search for releases | `action="search"` (`ids`, `confirm=true`) | `rustarr sonarr search --confirm` | — (raw `POST /api/v3/command`) |
| Refresh / rescan | `action="refresh"` (`ids`, `confirm=true`) | `rustarr sonarr refresh --confirm` | — (raw `POST /api/v3/command`) |
| Change quality profile | `action="set_quality", from, to, confirm=true` | `rustarr sonarr set-quality --from "SD" --to "HD-1080p" --confirm` | — (raw `PUT /api/v3/series/editor`) |
| Remove a show | `action="delete", id=<seriesId>, delete_files?, confirm=true` | `rustarr sonarr delete --id <seriesId> --delete-files --confirm` | `./scripts/sonarr.sh remove <tvdbId> [--delete-files]` |

`api_get <path>` above is shorthand for `mcp__rustarr__sonarr(action="api_get",
path="<path>")` / `rustarr sonarr get --path "<path>"` — the generic passthrough
used where no curated command exists. `api_get` requires `rustarr:write` scope.

## Examples

### Preferred (MCP)

```text
# Browse the library and the queue
mcp__rustarr__sonarr(action="list")
mcp__rustarr__sonarr(action="queue")

# Preview, then add "Severance" (preview omits confirm; add applies it)
mcp__rustarr__sonarr(action="add", term="Severance")
mcp__rustarr__sonarr(action="add", term="Severance",
  quality_profile="HD-1080p", root_folder="/tv", confirm=true)

# Kick off a search for everything monitored-but-missing
mcp__rustarr__sonarr(action="search", confirm=true)

# Remove a show by its Sonarr series id, keeping files
mcp__rustarr__sonarr(action="delete", id=42, confirm=true)
```

### Fallback (CLI)

```bash
rustarr sonarr list
rustarr sonarr add --term "Severance"                      # preview
rustarr sonarr add --term "Severance" --quality-profile "HD-1080p" \
  --root-folder /tv --confirm
rustarr sonarr delete --id 42 --confirm
```

### Last resort (direct API script)

```bash
./scripts/sonarr.sh search "Severance"     # numbered TVDB results
./scripts/sonarr.sh exists 371980          # is this TVDB id in the library?
./scripts/sonarr.sh add 371980             # add by TVDB id (searches by default)
./scripts/sonarr.sh remove 371980 --delete-files
./scripts/sonarr.sh config                 # root folders + quality profiles
```

## Workflow

When the user asks about TV shows:

1. **"Add Breaking Bad"** → preview with `add term="Breaking Bad"` (or the script's
   `search`), confirm the right match with the user, then re-run `add` with
   `confirm=true` plus a `quality_profile` and `root_folder`.
2. **"Is The Office in my library?"** → `list` and scan titles, or the script's
   `exists <tvdbId>`.
3. **"Remove Game of Thrones"** → find its **series id** via `list`, ask whether to
   delete files, then `delete id=<seriesId> [delete_files=true] confirm=true`.
4. **"What quality profiles do I have?"** → `quality_profiles`.

When adding, always present the resolved match (title + year) for confirmation
before applying — the preview (no-confirm) response carries it.

## Notes

- Sonarr uses the `/api/v3` API; the curated commands and the script both target it.
- Quality-profile and root-folder values are **names/paths**, resolved per
  installation — list them first (`quality_profiles`, `rootfolders`).
- `search` and `refresh` are async fire-and-forget jobs (`POST /command`); they
  return immediately and don't poll for completion.
- The direct-API script's `add`/`remove`/`exists` use TVDB ids; the MCP/CLI
  `add`/`delete` use a search term / Sonarr series id respectively.

## Reference

For the direct-API layer and deeper endpoint detail:

- **[API Endpoints](./references/api-endpoints.md)** — full endpoint reference
- **[Quick Reference](./references/quick-reference.md)** — copy-paste examples
- **[Troubleshooting](./references/troubleshooting.md)** — auth/connection/errors
- [Sonarr API docs](https://sonarr.tv/docs/api/) and [TVDB](https://thetvdb.com/)
