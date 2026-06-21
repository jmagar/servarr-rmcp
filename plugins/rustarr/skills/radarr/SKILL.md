---
name: radarr
description: >-
  This skill should be used when the user wants to manage movies in Radarr via
  the rustarr media stack. Triggers include "add a movie", "add to Radarr",
  "search Radarr", "find a film", "download a movie", "remove a movie", "delete
  movie", "is [movie] in my library", "Radarr queue", "Radarr wanted/missing",
  "Radarr health", or any mention of Radarr / movie library management.
---

# Radarr — Movie Management (via rustarr)

Search, add, monitor, and remove movies in Radarr. Radarr is an **ArrManager**
service in rustarr (so is Sonarr), exposing curated `list` / `search` / `add` /
`delete` style commands on top of the Radarr `/api/v3` REST API.

## Access model — try in this order

rustarr exposes every service three ways. Prefer the highest tier available:

1. **MCP tool (preferred)** — `mcp__rustarr__radarr(action="…", …)`. Works
   whenever the rustarr MCP server is connected; credentials live server-side.
2. **rustarr CLI (fallback)** — `rustarr radarr <verb> [flags]`. Use when the MCP
   server isn't connected but the `rustarr` binary is available (the plugin
   bundles it at `bin/rustarr`; it may also be on `PATH`). It talks to the
   upstreams directly using the same configured credentials.
3. **Direct API (last resort)** — `./scripts/radarr.sh <cmd>`. Bundled curl
   wrapper that hits Radarr's `/api/v3` directly, reading creds from
   `~/.rustarr/.env` (written by the plugin's `rustarr setup plugin-hook`) or the
   legacy `~/.config/lab-arrs/config.env`. Use only when neither rustarr surface
   is reachable.

**Writes are gated.** Every mutating action needs `confirm=true` (MCP) /
`--confirm` (CLI); without it you get a dry-run preview. Reads are unrestricted.

> Identifier note: the MCP/CLI `add` takes a **search term** (title) and `delete`
> takes the **Radarr movie id** (from `list`). The direct-API script instead uses
> **TMDB ids** for `add`/`remove`/`exists`. Don't mix them across tiers.

## Operations

| Intent | MCP (preferred) | CLI (fallback) | Direct API (last resort) |
|---|---|---|---|
| List library | `action="list"` (opts: `limit`, `offset`, `fields`) | `rustarr radarr list` | `api_get /api/v3/movie` |
| Wanted / missing | `action="wanted"` | `rustarr radarr wanted` | `api_get /api/v3/wanted/missing` |
| Download/import queue | `action="queue"` | `rustarr radarr queue` | `api_get /api/v3/queue` |
| Recent history | `action="history"` | `rustarr radarr history` | `api_get /api/v3/history` |
| Quality profiles | `action="quality_profiles"` | `rustarr radarr quality-profiles` | `./scripts/radarr.sh config` |
| Root folders | `action="rootfolders"` | `rustarr radarr rootfolders` | `./scripts/radarr.sh config` |
| Health checks | `action="health"` | `rustarr radarr health` | `api_get /api/v3/health` |
| Find a movie to add | `action="add", term="Dune"` (no confirm = preview) | `rustarr radarr add --term "Dune"` | `./scripts/radarr.sh search "Dune"` |
| Check if it exists | (find via `list`/`add` preview) | — | `./scripts/radarr.sh exists <tmdbId>` |
| Add a movie | `action="add", term, quality_profile, root_folder, confirm=true` | `rustarr radarr add --term "X" --quality-profile "HD-1080p" --root-folder /movies --confirm` | `./scripts/radarr.sh add <tmdbId> [profileId]` |
| Monitor / unmonitor | `action="monitor"` / `"unmonitor"` (`title` or `ids`, `confirm=true`) | `rustarr radarr monitor --title "X" --confirm` | — (raw `PUT /api/v3/movie/editor`) |
| Search for releases | `action="search"` (`ids`, `confirm=true`) | `rustarr radarr search --confirm` | — (raw `POST /api/v3/command`) |
| Refresh / rescan | `action="refresh"` (`ids`, `confirm=true`) | `rustarr radarr refresh --confirm` | — (raw `POST /api/v3/command`) |
| Change quality profile | `action="set_quality", from, to, confirm=true` | `rustarr radarr set-quality --from "SD" --to "HD-1080p" --confirm` | — (raw `PUT /api/v3/movie/editor`) |
| Remove a movie | `action="delete", id=<movieId>, delete_files?, confirm=true` | `rustarr radarr delete --id <movieId> --delete-files --confirm` | `./scripts/radarr.sh remove <tmdbId> [--delete-files]` |

`api_get <path>` above is shorthand for `mcp__rustarr__radarr(action="api_get",
path="<path>")` / `rustarr radarr get --path "<path>"` — the generic passthrough
used where no curated command exists. `api_get` requires `rustarr:write` scope.

## Examples

### Preferred (MCP)

```text
# Browse the library and the queue
mcp__rustarr__radarr(action="list")
mcp__rustarr__radarr(action="queue")

# Preview, then add "Dune: Part Two" (preview omits confirm; add applies it)
mcp__rustarr__radarr(action="add", term="Dune: Part Two")
mcp__rustarr__radarr(action="add", term="Dune: Part Two",
  quality_profile="HD-1080p", root_folder="/movies", confirm=true)

# Kick off a search for everything monitored-but-missing
mcp__rustarr__radarr(action="search", confirm=true)

# Remove a movie by its Radarr movie id, keeping files
mcp__rustarr__radarr(action="delete", id=42, confirm=true)
```

### Fallback (CLI)

```bash
rustarr radarr list
rustarr radarr add --term "Dune: Part Two"                 # preview
rustarr radarr add --term "Dune: Part Two" --quality-profile "HD-1080p" \
  --root-folder /movies --confirm
rustarr radarr delete --id 42 --confirm
```

### Last resort (direct API script)

```bash
./scripts/radarr.sh search "Dune"          # numbered TMDB results
./scripts/radarr.sh exists 693134          # is this TMDB id in the library?
./scripts/radarr.sh add 693134             # add by TMDB id (searches by default)
./scripts/radarr.sh remove 693134 --delete-files
./scripts/radarr.sh config                 # root folders + quality profiles
```

## Workflow

When the user asks about movies:

1. **"Add Dune"** → preview with `add term="Dune"` (or the script's `search`),
   confirm the right match with the user, then re-run `add` with `confirm=true`
   plus a `quality_profile` and `root_folder`.
2. **"Is Inception in my library?"** → `list` and scan titles, or the script's
   `exists <tmdbId>`.
3. **"Remove The Matrix"** → find its **movie id** via `list`, ask whether to
   delete files, then `delete id=<movieId> [delete_files=true] confirm=true`.
4. **"What quality profiles do I have?"** → `quality_profiles`.

When adding, always present the resolved match (title + year) for confirmation
before applying — the preview (no-confirm) response carries it.

## Notes

- Radarr uses the `/api/v3` API; the curated commands and the script both target it.
- Quality-profile and root-folder values are **names/paths**, resolved per
  installation — list them first (`quality_profiles`, `rootfolders`).
- `search` and `refresh` are async fire-and-forget jobs (`POST /command`); they
  return immediately and don't poll for completion.
- The direct-API script's `add`/`remove`/`exists` use TMDB ids; the MCP/CLI
  `add`/`delete` use a search term / Radarr movie id respectively.

## Reference

For the direct-API layer and deeper endpoint detail:

- **[API Endpoints](./references/api-endpoints.md)** — full endpoint reference
- **[Quick Reference](./references/quick-reference.md)** — copy-paste examples
- **[Troubleshooting](./references/troubleshooting.md)** — auth/connection/errors
- [Radarr API docs](https://radarr.video/docs/api/) and [TMDB](https://themoviedb.org/)
