---
name: overseerr
description: >-
  This skill should be used when the user wants to request movies or TV shows
  via Overseerr, monitor or manage media requests, or check request status.
  Triggers include "request a movie", "request a TV show", "add to Overseerr",
  "check request status", "pending requests", "is my request done", "Overseerr
  status", or any mention of Overseerr media requesting.
---

# Overseerr — Media Requests (via rustarr)

Search, request, approve, and decline movie/TV requests in Overseerr. Overseerr
is the **Requests** capability in rustarr, exposing curated `requests` /
`request_search` / `request_create` / `request_approve` / `request_decline`
commands on top of the Overseerr `/api/v1` REST API.

## Access model — try in this order

rustarr exposes every service three ways. Prefer the highest tier available:

1. **MCP tool (preferred)** — `mcp__rustarr__overseerr(action="…", …)`. Works
   whenever the rustarr MCP server is connected; credentials live server-side.
2. **rustarr CLI (fallback)** — `rustarr overseerr <verb> [flags]`. Use when the
   MCP server isn't connected but the `rustarr` binary is available (the plugin
   bundles it at `bin/rustarr`; it may also be on `PATH`). It talks to the
   upstreams directly using the same configured credentials.
3. **Direct API (last resort)** — `node ./scripts/<name>.mjs <args>`. Bundled
   Node scripts that hit Overseerr's `/api/v1` directly, reading creds from
   `~/.rustarr/.env` (written by the plugin's `rustarr setup plugin-hook`) or the
   legacy `~/.config/lab-arrs/config.env`. Use only when neither rustarr surface
   is reachable.

**Writes are gated.** Every mutating action needs `confirm=true` (MCP) /
`--confirm` (CLI); without it the call is rejected and nothing is changed. Reads are unrestricted.

> Identifier note: `request_create` takes a **TMDB id** as `media_id` (from
> `request_search`), plus a `media_type` of `movie` or `tv`. `request_approve` /
> `request_decline` take the **Overseerr request id** (from `requests`), and need
> an admin / MANAGE_REQUESTS API key. Don't mix TMDB ids and request ids.

## Operations

| Intent | MCP (preferred) | CLI (fallback) | Direct API (last resort) |
|---|---|---|---|
| List requests | `action="requests"` (opts: `filter`, `take`, `skip`) | `rustarr overseerr requests --filter pending` | `node ./scripts/requests.mjs --filter pending` |
| List requests (titles resolved) | `action="requests"` then inspect | — | `node ./scripts/requests-enriched.mjs --filter pending` |
| Search titles to request | `action="request_search", query="Dune"` | `rustarr overseerr search --query "Dune"` | `node ./scripts/search.mjs "Dune" --type movie` |
| Request a movie | `action="request_create", media_type="movie", media_id=438631, confirm=true` | `rustarr overseerr request --media-type movie --media-id 438631 --confirm` | `node ./scripts/request.mjs "Dune" --type movie --mediaId 438631` |
| Request a TV show | `action="request_create", media_type="tv", media_id=95396, seasons=[1,2], confirm=true` | `rustarr overseerr request --media-type tv --media-id 95396 --season 1 --season 2 --confirm` | `node ./scripts/request.mjs "Severance" --type tv --mediaId 95396 --seasons 1,2` |
| Approve a request | `action="request_approve", id=123, confirm=true` | `rustarr overseerr approve --id 123 --confirm` | `node ./scripts/approve-request.mjs 123` |
| Decline a request | `action="request_decline", id=123, confirm=true` | `rustarr overseerr decline --id 123 --confirm` | `node ./scripts/decline-request.mjs 123` |
| Inspect one request | `api_get /api/v1/request/123` | `rustarr overseerr get --path "/api/v1/request/123"` | `node ./scripts/request-by-id.mjs 123` |
| Delete a request | `api_delete /api/v1/request/123` | `rustarr overseerr delete --path "/api/v1/request/123" --confirm` | `node ./scripts/delete-request.mjs 123` |
| Watch request status | (poll `requests`) | — | `node ./scripts/monitor.mjs --interval 30 --filter pending` |

`api_get <path>` above is shorthand for `mcp__rustarr__overseerr(action="api_get",
path="<path>")` / `rustarr overseerr get --path "<path>"` — the generic passthrough
used where no curated command exists. `api_get` requires `rustarr:write` scope.
Generic reads: `api_get /api/v1/request?filter=pending`,
`api_get /api/v1/request?take=20`.

## Examples

### Preferred (MCP)

```text
# See what is pending approval
mcp__rustarr__overseerr(action="requests", filter="pending")

# Search to get the TMDB id, then request the movie
mcp__rustarr__overseerr(action="request_search", query="Dune")
mcp__rustarr__overseerr(action="request_create", media_type="movie",
  media_id=438631, confirm=true)

# Request specific TV seasons by TMDB id
mcp__rustarr__overseerr(action="request_create", media_type="tv",
  media_id=95396, seasons=[1,2], confirm=true)

# Approve, then decline, by Overseerr request id
mcp__rustarr__overseerr(action="request_approve", id=123, confirm=true)
mcp__rustarr__overseerr(action="request_decline", id=124, confirm=true)
```

### Fallback (CLI)

```bash
rustarr overseerr requests --filter pending
rustarr overseerr search --query "Dune"
rustarr overseerr request --media-type movie --media-id 438631 --confirm
rustarr overseerr request --media-type tv --media-id 95396 --season 1 --season 2 --confirm
rustarr overseerr approve --id 123 --confirm
rustarr overseerr decline --id 124 --confirm
```

### Last resort (direct API script)

```bash
node ./scripts/requests.mjs --filter pending          # list pending requests
node ./scripts/search.mjs "Dune" --type movie         # results carry the TMDB id
node ./scripts/request.mjs "Dune" --type movie --mediaId 438631
node ./scripts/request.mjs "Severance" --type tv --mediaId 95396 --seasons 1,2
node ./scripts/approve-request.mjs 123                 # approve by request id
node ./scripts/decline-request.mjs 124                 # decline by request id
```

## Workflow

When the user asks about media requests:

1. **"Request Dune"** → `request_search query="Dune"` (or the script's `search`) to
   resolve the **TMDB id**, confirm the right match with the user, then
   `request_create media_type="movie" media_id=<tmdb> confirm=true`.
2. **"Add Bluey to my library"** → search as `tv`, then `request_create` with
   `media_type="tv"` (all seasons unless the user names specific ones).
3. **"What's pending?"** → `requests filter="pending"`.
4. **"Approve my Oppenheimer request"** → find its **request id** via `requests`,
   then `request_approve id=<requestId> confirm=true` (needs an admin API key).
5. **"Decline request 124"** → `request_decline id=124 confirm=true`.

Typical flow: **search (get the TMDB id) → create → approve.** Always present the
resolved match (title + year) for confirmation before creating a request — the
search results carry the TMDB id you feed into `request_create`.

## Notes

- Overseerr uses the `/api/v1` API; the curated commands and the scripts both
  target it.
- `request_create` needs a **TMDB id** (`media_id`) plus `media_type`; for TV,
  `seasons` is an optional int list (default: all seasons).
- `request_approve` / `request_decline` act on the **Overseerr request id** and
  require an account with MANAGE_REQUESTS (admin) on the configured API key.
- Request statuses surface as `pending` (awaiting approval), `approved`/
  `processing` (being fetched by Sonarr/Radarr), and `available` (ready in Plex).
- Overseerr coordinates with Sonarr/Radarr for the actual downloads; the
  `monitor.mjs` script polls for status changes, but webhooks can also push them.

## Reference

For the direct-API layer and deeper endpoint detail:

- **[API Endpoints](./references/api-endpoints.md)** — full endpoint reference
- **[Quick Reference](./references/quick-reference.md)** — copy-paste examples
- **[Troubleshooting](./references/troubleshooting.md)** — auth/connection/errors
- `./references/overseerr-api.yml` — raw OpenAPI source snapshot
- [Overseerr API docs](https://api-docs.overseerr.dev/) and [Overseerr GitHub](https://github.com/sct/overseerr)
