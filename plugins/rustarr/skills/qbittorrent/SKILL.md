---
name: qbittorrent
description: >-
  This skill should be used when the user asks about torrents, downloading,
  seeding, or the qBittorrent client via the rustarr media stack. Triggers
  include "what's downloading", "list torrents", "add a torrent", "add a magnet",
  "pause/resume/remove torrent", "torrent speed", "download queue", "qbit",
  "qBittorrent status", "check download status", or any mention of managing a
  torrent client.
---

# qBittorrent — Torrent Management (via rustarr)

Monitor and control qBittorrent torrents. qBittorrent is a **DownloadClient**
service in rustarr (so is SABnzbd), exposing curated `download_queue` /
`download_add` / `download_pause` / `download_resume` / `download_remove`
commands on top of the qBittorrent WebUI `/api/v2` REST surface.

## Access model — try in this order

rustarr exposes every service three ways. Prefer the highest tier available:

1. **MCP tool (preferred)** — `mcp__rustarr__qbittorrent(action="…", …)`. Works
   whenever the rustarr MCP server is connected; credentials live server-side.
2. **rustarr CLI (fallback)** — `rustarr qbittorrent <verb> [flags]`. Use when the
   MCP server isn't connected but the `rustarr` binary is available (the plugin
   bundles it at `bin/rustarr`; it may also be on `PATH`). It talks to the
   upstreams directly using the same configured credentials.
3. **Direct API (last resort)** — `./scripts/qbit-api.sh <cmd>`. Bundled curl
   wrapper that logs in to qBittorrent's WebUI and hits `/api/v2` directly,
   reading creds from `~/.rustarr/.env` (written by the plugin's `rustarr setup
   plugin-hook`) or the legacy `~/.config/lab-arrs/config.env`. Use only when
   neither rustarr surface is reachable.

**Writes are gated.** Every mutating action needs `confirm=true` (MCP) /
`--confirm` (CLI); without it the call is rejected and nothing is changed. Reads are unrestricted.

> Identifier note: qBittorrent identifies a torrent by its **hash**, exposed
> across the MCP/CLI tiers as `hash` / `--hash` (the curated DownloadClient
> commands also accept `--id` as an alias, but qBittorrent is hash-native). The
> direct-API script uses the same `hash`. Get it from `download_queue` / `list`.

## Operations

| Intent | MCP (preferred) | CLI (fallback) | Direct API (last resort) |
|---|---|---|---|
| List torrents | `action="download_queue"` | `rustarr qbittorrent queue` | `./scripts/qbit-api.sh list` |
| Service status / running? | `action="service_status"` | `rustarr qbittorrent status` | `./scripts/qbit-api.sh version` |
| Add a torrent / magnet | `action="download_add", url="<magnet-or-url>", confirm=true` | `rustarr qbittorrent add --url "<magnet-or-url>" --confirm` | `./scripts/qbit-api.sh add "<magnet-or-url>"` |
| Pause one torrent | `action="download_pause", hash="<hash>", confirm=true` | `rustarr qbittorrent pause --hash <hash> --confirm` | `./scripts/qbit-api.sh pause <hash>` |
| Pause all torrents | `action="download_pause", confirm=true` | `rustarr qbittorrent pause --confirm` | `./scripts/qbit-api.sh pause all` |
| Resume one torrent | `action="download_resume", hash="<hash>", confirm=true` | `rustarr qbittorrent resume --hash <hash> --confirm` | `./scripts/qbit-api.sh resume <hash>` |
| Resume all torrents | `action="download_resume", confirm=true` | `rustarr qbittorrent resume --confirm` | `./scripts/qbit-api.sh resume all` |
| Remove a torrent | `action="download_remove", hash="<hash>", delete_files?, confirm=true` | `rustarr qbittorrent remove --hash <hash> --delete-files --confirm` | `./scripts/qbit-api.sh delete <hash> [--files]` |
| Raw torrent JSON | `api_get /api/v2/torrents/info` | `rustarr qbittorrent get --path "/api/v2/torrents/info"` | `./scripts/qbit-api.sh list` |
| Global transfer stats | `api_get /api/v2/transfer/info` | `rustarr qbittorrent get --path "/api/v2/transfer/info"` | `./scripts/qbit-api.sh transfer` |

`api_get <path>` above is shorthand for `mcp__rustarr__qbittorrent(action="api_get",
path="<path>")` / `rustarr qbittorrent get --path "<path>"` — the generic
passthrough used where no curated command exists. `api_get` requires
`rustarr:write` scope.

## Examples

### Preferred (MCP)

```text
# See what's downloading/seeding and confirm qBittorrent is up
mcp__rustarr__qbittorrent(action="download_queue")
mcp__rustarr__qbittorrent(action="service_status")

# Add a magnet link (writes need confirm=true)
mcp__rustarr__qbittorrent(action="download_add",
  url="magnet:?xt=urn:btih:...", confirm=true)

# Pause everything, then resume everything
mcp__rustarr__qbittorrent(action="download_pause", confirm=true)
mcp__rustarr__qbittorrent(action="download_resume", confirm=true)

# Remove one torrent by its hash, keeping files on disk
mcp__rustarr__qbittorrent(action="download_remove",
  hash="8c212779b4abde7c6bc608063a0d008b7e40ce32", confirm=true)
```

### Fallback (CLI)

```bash
rustarr qbittorrent queue
rustarr qbittorrent add --url "magnet:?xt=urn:btih:..." --confirm
rustarr qbittorrent pause --confirm                  # pause all
rustarr qbittorrent resume --hash <hash> --confirm   # resume one
rustarr qbittorrent remove --hash <hash> --delete-files --confirm
```

### Last resort (direct API script)

```bash
./scripts/qbit-api.sh list                  # all torrents
./scripts/qbit-api.sh add "magnet:?xt=urn:btih:..."
./scripts/qbit-api.sh pause all             # pause/stop all
./scripts/qbit-api.sh resume <hash>         # resume/start one
./scripts/qbit-api.sh delete <hash> --files
./scripts/qbit-api.sh version               # is the WebUI up?
```

## Workflow

When the user asks about torrents:

1. **"What's downloading?"** → `download_queue` and report active torrents
   (name, progress, down/up speed, ETA).
2. **"Add this magnet"** → `download_add url="<magnet-or-url>" confirm=true`. Without
   `confirm` the call is rejected and nothing is added.
3. **"Pause / resume torrents"** → `download_pause` / `download_resume` with no hash
   to act on every torrent, or `hash="<hash>"` to target one.
4. **"Remove that torrent"** → find its **hash** via `download_queue`, ask whether
   to delete files, then `download_remove hash="<hash>" [delete_files=true]
   confirm=true`.

Always confirm the target torrent (name + hash) with the user before a remove,
especially with `delete_files=true`.

## Notes

- qBittorrent uses the WebUI `/api/v2` API; the curated commands and the script
  both target it. qBittorrent 5.x renamed the pause/resume endpoints to
  stop/start — the direct-API script handles that compatibility detail; the MCP
  and CLI tiers normalize it for you.
- qBittorrent identifies torrents by **hash** (exposed as `hash` / `--hash`);
  SABnzbd identifies downloads by **nzo_id** — don't mix identifiers across the
  two DownloadClient services.
- Omitting `hash`/`id` on pause/resume acts on **all torrents**; supply one to
  target a single torrent.
- `download_remove` with `delete_files=true` permanently deletes downloaded data —
  always confirm before running it.

## Reference

For the direct-API layer and deeper endpoint detail:

- **[API Endpoints](./references/api-endpoints.md)** — full endpoint reference
- **[Quick Reference](./references/quick-reference.md)** — copy-paste examples
- **[Troubleshooting](./references/troubleshooting.md)** — login/CSRF/connection/errors
- [qBittorrent WebUI API docs](https://github.com/qbittorrent/qBittorrent/wiki/WebUI-API-(qBittorrent-5.0))
