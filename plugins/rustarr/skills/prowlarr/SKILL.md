---
name: prowlarr
description: This skill should be used when the user asks to search indexers, find a release, check indexer status or health, list indexers, view indexer stats, test indexer connectivity, sync indexers to Sonarr or Radarr, connect Prowlarr to another app, or mentions Prowlarr or indexer management via the rustarr media stack.
---

# Prowlarr — Indexer Management (via rustarr)

Search across all your indexers and monitor indexer health in Prowlarr. Prowlarr
is an **Indexer** service in rustarr, exposing curated `indexers` / `search` /
`stats` / `test` commands on top of the Prowlarr `/api/v1` REST API.

## Access model — try in this order

rustarr exposes every service three ways. Prefer the highest tier available:

1. **MCP tool (preferred)** — `mcp__rustarr__prowlarr(action="…", …)`. Works
   whenever the rustarr MCP server is connected; credentials live server-side.
2. **rustarr CLI (fallback)** — `rustarr prowlarr <verb> [flags]`. Use when the
   MCP server isn't connected but the `rustarr` binary is available (the plugin
   bundles it at `bin/rustarr`; it may also be on `PATH`). It talks to the
   upstreams directly using the same configured credentials.
3. **Direct API (last resort)** — `./scripts/prowlarr-api.sh <cmd>`. Bundled curl
   wrapper that hits Prowlarr's `/api/v1` directly, reading creds from
   `~/.rustarr/.env` (written by the plugin's `rustarr setup plugin-hook`) or the
   legacy `~/.config/lab-arrs/config.env`. Use only when neither rustarr surface
   is reachable.

**Writes are gated.** Every mutating action needs `confirm=true` (MCP) /
`--confirm` (CLI); without it the call is rejected and nothing is changed. Reads
are unrestricted.

## Operations

| Intent | MCP (preferred) | CLI (fallback) | Direct API (last resort) |
|---|---|---|---|
| List indexers | `action="indexers"` | `rustarr prowlarr indexers` | `./scripts/prowlarr-api.sh indexers` |
| Search indexers | `action="indexer_search", query="ubuntu 24.04"` (opt: `ids`) | `rustarr prowlarr search --query "ubuntu 24.04"` | `./scripts/prowlarr-api.sh search "ubuntu 24.04"` |
| Per-indexer stats | `action="indexer_stats"` | `rustarr prowlarr stats` | `./scripts/prowlarr-api.sh stats` |
| Test indexer(s) | `action="indexer_test", id?, confirm=true` | `rustarr prowlarr test --id <id> --confirm` | `./scripts/prowlarr-api.sh test <id>` / `test-all` |
| System status | `action="service_status"` or `api_get /api/v1/system/status` | `rustarr prowlarr status` | `./scripts/prowlarr-api.sh status` |
| Health checks | `api_get /api/v1/health` | `rustarr prowlarr get --path "/api/v1/health"` | `./scripts/prowlarr-api.sh health` |
| List connected apps | `api_get /api/v1/applications` | `rustarr prowlarr get --path "/api/v1/applications"` | `./scripts/prowlarr-api.sh apps` |
| Sync indexers to apps | `api_post /api/v1/command` (body `{"name":"ApplicationIndexerSync"}`, confirm) | `rustarr prowlarr post --path "/api/v1/command" --body '{"name":"ApplicationIndexerSync"}' --confirm` | `./scripts/prowlarr-api.sh sync` |
| Enable / disable / delete indexer | `api_put` / `api_delete /api/v1/indexer/<id>` (confirm) | `rustarr prowlarr put\|delete --path "/api/v1/indexer/<id>" --confirm` | `./scripts/prowlarr-api.sh enable\|disable\|delete <id>` |

`api_get <path>` above is shorthand for `mcp__rustarr__prowlarr(action="api_get",
path="<path>")` / `rustarr prowlarr get --path "<path>"` — the generic passthrough
used where no curated command exists. `api_get` requires `rustarr:write` scope
(so do `api_post`, `api_put`, and `api_delete`). Useful generic reads:
`/api/v1/indexer`, `/api/v1/system/status`, `/api/v1/health`.

## Examples

### Preferred (MCP)

```text
# List configured indexers and their per-indexer stats
mcp__rustarr__prowlarr(action="indexers")
mcp__rustarr__prowlarr(action="indexer_stats")

# Manual search across all indexers, then restrict to specific indexer ids
mcp__rustarr__prowlarr(action="indexer_search", query="ubuntu 24.04")
mcp__rustarr__prowlarr(action="indexer_search", query="ubuntu 24.04", ids=[3, 7])

# Test every indexer (omit id) or just one; writes need confirm
mcp__rustarr__prowlarr(action="indexer_test", confirm=true)
mcp__rustarr__prowlarr(action="indexer_test", id=3, confirm=true)
```

### Fallback (CLI)

```bash
rustarr prowlarr indexers
rustarr prowlarr search --query "ubuntu 24.04"
rustarr prowlarr search --query "ubuntu 24.04" --id 3
rustarr prowlarr stats
rustarr prowlarr test --confirm                 # all indexers
rustarr prowlarr test --id 3 --confirm
```

### Last resort (direct API script)

```bash
./scripts/prowlarr-api.sh indexers              # id / name / protocol / enabled / priority
./scripts/prowlarr-api.sh search "ubuntu 24.04" # Newznab-style search across indexers
./scripts/prowlarr-api.sh stats                 # per-indexer query/grab/failure counters
./scripts/prowlarr-api.sh test-all              # test connectivity for all indexers
./scripts/prowlarr-api.sh sync                  # push indexer config to Sonarr/Radarr/etc
./scripts/prowlarr-api.sh health                # health-check warnings
```

## Workflow

When the user asks about indexers or searches:

1. **"Search for the latest Ubuntu ISO"** → `indexer_search query="ubuntu 24.04"`
   (or the script's `search`), then present titles with their download/info links.
2. **"Which indexers are working?"** → `indexer_stats` for query/grab/failure
   counters, then `indexer_test confirm=true` to actively verify connectivity.
3. **"List my indexers"** → `indexers` (id, name, enable, protocol, priority).
4. **"Test indexer 3"** → `indexer_test id=3 confirm=true`; omit `id` to test all.
5. **"Sync indexers to Sonarr"** → there is no curated command; use the
   `ApplicationIndexerSync` passthrough (`api_post /api/v1/command`) or the
   script's `sync`. Confirm before pushing changes to connected apps.

When restricting a search to particular indexers, pass their ids (from `indexers`)
via `ids` (MCP) / `--id` (CLI).

## Notes

- Prowlarr uses the `/api/v1` API; the curated commands and the script both target it.
- Curated coverage is `indexers`, `indexer_search`, `indexer_stats`, and
  `indexer_test`. App sync, enable/disable/delete, and app listing have no curated
  command — reach them via the `api_get`/`api_post`/`api_put`/`api_delete`
  passthrough (above) or the direct-API script.
- `indexer_search` queries **external** indexers — respect rate limits.
- **Indexer deletion is permanent** — always confirm before removing one. The
  passthrough `api_delete /api/v1/indexer/<id>` and the script's `delete` both need
  the deliberate confirm/`--confirm` step.
- Category IDs (2000=Movies, 5000=TV, 3000=Audio, 7000=Books, …) follow
  Newznab/Torznab standards; the direct-API `search` accepts `--category` and
  `--torrents`/`--usenet` filters.

## Reference

For the direct-API layer and deeper endpoint detail:

- **[API Endpoints](./references/api-endpoints.md)** — full endpoint reference
- **[Quick Reference](./references/quick-reference.md)** — copy-paste examples
- **[Troubleshooting](./references/troubleshooting.md)** — auth/connection/errors
- [Prowlarr API docs](https://prowlarr.com/docs/api/) — upstream `/api/v1` reference
