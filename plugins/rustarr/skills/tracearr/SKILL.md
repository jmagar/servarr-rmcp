---
name: tracearr
description: This skill should be used when working with Tracearr media-server monitoring for Plex, Jellyfin, or Emby, including active streams, stream analytics, account-sharing detection, trust scores, alerts, Tautulli/Jellystat imports, Docker deployment, arrs plugin configuration, or Tracearr's public API.
---

# Tracearr — Media-Server Monitoring (via rustarr)

Monitor Plex, Jellyfin, and Emby through Tracearr: active streams, stream
analytics, geolocation, bandwidth, transcodes, device usage, library metrics,
trust scores, account-sharing detection, and alerts.

Tracearr is a **GenericOnly** service in rustarr — it has **no curated verbs**
(no `streams`, no `servers`, no `sessions`). It is reachable only through the
generic passthrough actions: `service_status`, `api_get`, `api_post`, `api_put`,
`api_delete`, `help`, and `integrations`. Every operation below is one of those
generic calls against a documented Tracearr path.

## Access model — try in this order

rustarr exposes Tracearr three ways. Prefer the highest tier available:

1. **MCP tool (preferred)** — `mcp__rustarr__tracearr(action="…", …)`. Works
   whenever the rustarr MCP server is connected; credentials live server-side.
   Read with `action="service_status"` or `action="api_get", path="/health"` /
   `path="/api/v1/…"`; write with `action="api_post|api_put|api_delete",
   path="/api/v1/…", body={…}, confirm=true`.
2. **rustarr CLI (fallback)** — `rustarr tracearr <verb> [flags]`. Use when the
   MCP server isn't connected but the `rustarr` binary is available (the plugin
   bundles it at `bin/rustarr`; it may also be on `PATH`). It talks to the
   upstream directly using the same configured credentials. Reads:
   `rustarr tracearr status` or `rustarr tracearr get --path "/api/v1/…"`.
   Writes: `rustarr tracearr post|put|delete --path "/api/v1/…" --body '{…}'
   --confirm`.
3. **Direct API (last resort)** — `./scripts/tracearr-api.sh <cmd>`. Bundled
   curl wrapper that hits Tracearr's REST routes directly, reading creds from
   rustarr's materialized env (`~/.rustarr/.env`), `~/.lab/.env`, or the legacy
   `~/.config/lab-arrs/config.env`. It sends `TRACEARR_API_KEY` as a bearer
   token when present. Use only when neither rustarr surface is reachable.

**Writes are gated.** Every mutating call (`api_post` / `api_put` /
`api_delete`) needs `confirm=true` (MCP) / `--confirm` (CLI); without it the call
is rejected and nothing is changed. Reads are unrestricted.

> Auth + path notes: the rustarr passthrough applies the Bearer token exactly
> once and allowlists paths to **`/health` and `/api/v1` only** — so the MCP and
> CLI tiers must use `/api/v1/…` paths. The direct-API **script** targets
> Tracearr's own REST routes (`/api/streams`, `/api/servers`, `/api/alerts`,
> `/api-docs`), which sit outside that allowlist — it reaches them precisely
> because it bypasses rustarr. Don't paste API keys, user IP addresses, or
> account-sharing evidence into examples; treat all of it as sensitive.

`api_get <path>` below is shorthand for `mcp__rustarr__tracearr(action="api_get",
path="<path>")` / `rustarr tracearr get --path "<path>"` — the generic
passthrough. It requires `rustarr:write` scope (so do `api_post` / `api_put` /
`api_delete`); they are arbitrary upstream passthroughs.

## Operations

| Intent | MCP (preferred) | CLI (fallback) | Direct API (last resort) |
|---|---|---|---|
| Health check | `action="service_status"` (or `api_get path="/health"`) | `rustarr tracearr status` | `./scripts/tracearr-api.sh health` |
| Browse the API surface | `api_get path="/api/v1"` | `rustarr tracearr get --path "/api/v1"` | `./scripts/tracearr-api.sh api-docs` |
| Active streams | `api_get path="/api/v1/streams"` | `rustarr tracearr get --path "/api/v1/streams"` | `./scripts/tracearr-api.sh streams` |
| Monitored servers | `api_get path="/api/v1/servers"` | `rustarr tracearr get --path "/api/v1/servers"` | `./scripts/tracearr-api.sh servers` |
| Alerts | `api_get path="/api/v1/alerts"` | `rustarr tracearr get --path "/api/v1/alerts"` | `./scripts/tracearr-api.sh alerts` |
| Arbitrary read | `api_get path="/api/v1/<path>"` | `rustarr tracearr get --path "/api/v1/<path>"` | `./scripts/tracearr-api.sh get <path>` |
| Arbitrary write | `action="api_post", path="/api/v1/<path>", body={…}, confirm=true` | `rustarr tracearr post --path "/api/v1/<path>" --body '{…}' --confirm` | — (script is read-only) |

The script's `streams` / `servers` / `alerts` commands hit `/api/streams`,
`/api/servers`, and `/api/alerts` respectively; `get <path>` GETs any path you
pass. The script is read-only (no write commands) — for writes, use the MCP or
CLI passthrough.

## Examples

### Preferred (MCP)

```text
# Is Tracearr up?
mcp__rustarr__tracearr(action="service_status")

# Read active streams and monitored servers via the generic passthrough
mcp__rustarr__tracearr(action="api_get", path="/api/v1/streams")
mcp__rustarr__tracearr(action="api_get", path="/api/v1/servers")

# Writes need confirm=true (without it the call is rejected, nothing changes)
mcp__rustarr__tracearr(action="api_post", path="/api/v1/alerts",
  body={"name": "impossible-travel"}, confirm=true)
```

### Fallback (CLI)

```bash
rustarr tracearr status
rustarr tracearr get --path "/api/v1/streams"
rustarr tracearr get --path "/api/v1/servers"
rustarr tracearr post --path "/api/v1/alerts" --body '{"name":"impossible-travel"}' --confirm
```

### Last resort (direct API script)

```bash
./scripts/tracearr-api.sh health      # probe base URL, prints HTTP status
./scripts/tracearr-api.sh streams     # GET /api/streams
./scripts/tracearr-api.sh servers     # GET /api/servers
./scripts/tracearr-api.sh alerts      # GET /api/alerts
./scripts/tracearr-api.sh get /api/streams/active   # GET an arbitrary path
./scripts/tracearr-api.sh api-docs    # Swagger UI / API docs page
```

## Workflow

When the user asks about Tracearr:

1. **"Is Tracearr up?"** → `service_status` (MCP) / `rustarr tracearr status`
   (CLI) / `tracearr-api.sh health` (script).
2. **"Who's streaming right now?"** → `api_get path="/api/v1/streams"`, or the
   script's `streams`.
3. **"What media servers are monitored?"** → `api_get path="/api/v1/servers"`,
   or the script's `servers`.
4. **"Show my alert rules"** → `api_get path="/api/v1/alerts"`, or the script's
   `alerts`.
5. **Changing alert rules or imports** → these are writes; pass `confirm=true` /
   `--confirm` (without it the call is rejected, nothing changes). Confirm with
   the user before any destructive or privacy-sensitive action (deleting imports,
   exposing account-sharing details).

Because Tracearr is GenericOnly, when you don't know the exact path, browse the
API surface first (`api_get path="/api/v1"`, or the script's `api-docs`) before
guessing endpoints.

## Notes

- Tracearr is **GenericOnly** in rustarr — no curated verbs. Everything routes
  through `service_status` / `api_get` / `api_post` / `api_put` / `api_delete`.
- The rustarr passthrough is allowlisted to `/health` and `/api/v1`; use
  `/api/v1/…` paths on the MCP and CLI tiers.
- The direct-API script reaches Tracearr's own routes (`/api/streams`,
  `/api/servers`, `/api/alerts`, `/api-docs`) by bypassing rustarr — it is
  read-only.
- Tracearr's public REST API is read-only and requires an API key generated in
  Tracearr settings; Swagger UI lives at `/api-docs`.
- Treat API keys, webhook URLs, user IP addresses, and account-sharing evidence
  as sensitive — never paste them into examples.

## Reference

Tracearr has no bundled `references/` docs. For discovery and deeper detail:

- `mcp__rustarr__tracearr(action="help")` — registry-derived action help (no
  scope required).
- `mcp__rustarr__tracearr(action="integrations")` — confirm Tracearr is a
  configured rustarr service and see its kind/URL.
- `mcp__rustarr__tracearr(action="api_get", path="/api/v1")` or the script's
  `api-docs` — Tracearr's live API surface / Swagger UI.
