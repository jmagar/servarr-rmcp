---
name: sabnzbd
description: >-
  This skill should be used when the user wants to manage Usenet downloads with
  SABnzbd via the rustarr media stack. Triggers include "what's downloading",
  "SABnzbd status", "NZB queue", "add NZB", "pause downloads", "resume
  downloads", "remove a download", "retry failed downloads", "SAB history",
  "download queue", "is SABnzbd running", or any mention of Usenet download
  management.
---

# SABnzbd — Usenet Download Management (via rustarr)

Monitor and control the SABnzbd Usenet download queue. SABnzbd is a
**DownloadClient** service in rustarr (so is qBittorrent), exposing curated
`download_queue` / `download_add` / `download_pause` / `download_resume` /
`download_remove` commands on top of the SABnzbd `/api` REST surface.

## Access model — try in this order

rustarr exposes every service three ways. Prefer the highest tier available:

1. **MCP tool (preferred)** — `mcp__rustarr__sabnzbd(action="…", …)`. Works
   whenever the rustarr MCP server is connected; credentials live server-side.
2. **rustarr CLI (fallback)** — `rustarr sabnzbd <verb> [flags]`. Use when the MCP
   server isn't connected but the `rustarr` binary is available (the plugin
   bundles it at `bin/rustarr`; it may also be on `PATH`). It talks to the
   upstreams directly using the same configured credentials.
3. **Direct API (last resort)** — `./scripts/sab-api.sh <cmd>`. Bundled curl
   wrapper that hits SABnzbd's `/api` directly, reading creds from
   `~/.rustarr/.env` (written by the plugin's `rustarr setup plugin-hook`) or the
   legacy `~/.config/lab-arrs/config.env`. Use only when neither rustarr surface
   is reachable.

**Writes are gated.** Every mutating action needs `confirm=true` (MCP) /
`--confirm` (CLI); without it the call is rejected and nothing is changed. Reads are unrestricted.

> Identifier note: SABnzbd identifies a download by its **nzo_id**, exposed across
> the MCP/CLI tiers as `id` / `--id` (the curated DownloadClient commands also
> accept `--hash` as an alias, but SABnzbd is nzo_id-native). The direct-API
> script uses the same `nzo_id`. Get it from `download_queue` / `queue`.

## Operations

| Intent | MCP (preferred) | CLI (fallback) | Direct API (last resort) |
|---|---|---|---|
| List the queue | `action="download_queue"` | `rustarr sabnzbd queue` | `./scripts/sab-api.sh queue` |
| Service status / running? | `action="service_status"` | `rustarr sabnzbd status` | `./scripts/sab-api.sh status` |
| Add an NZB | `action="download_add", url="<nzb-url>", confirm=true` | `rustarr sabnzbd add --url "<nzb-url>" --confirm` | `./scripts/sab-api.sh add "<nzb-url>"` |
| Pause one download | `action="download_pause", id="<nzo_id>", confirm=true` | `rustarr sabnzbd pause --id <nzo_id> --confirm` | `./scripts/sab-api.sh pause-job <nzo_id>` |
| Pause all downloads | `action="download_pause", confirm=true` | `rustarr sabnzbd pause --confirm` | `./scripts/sab-api.sh pause` |
| Resume one download | `action="download_resume", id="<nzo_id>", confirm=true` | `rustarr sabnzbd resume --id <nzo_id> --confirm` | `./scripts/sab-api.sh resume-job <nzo_id>` |
| Resume all downloads | `action="download_resume", confirm=true` | `rustarr sabnzbd resume --confirm` | `./scripts/sab-api.sh resume` |
| Remove a download | `action="download_remove", id="<nzo_id>", delete_files?, confirm=true` | `rustarr sabnzbd remove --id <nzo_id> --delete-files --confirm` | `./scripts/sab-api.sh delete <nzo_id> [--files]` |
| Raw queue JSON | `api_get /api?mode=queue&output=json` | `rustarr sabnzbd get --path "/api?mode=queue&output=json"` | `./scripts/sab-api.sh queue` |

`api_get <path>` above is shorthand for `mcp__rustarr__sabnzbd(action="api_get",
path="<path>")` / `rustarr sabnzbd get --path "<path>"` — the generic passthrough
used where no curated command exists. `api_get` requires `rustarr:write` scope.

## Examples

### Preferred (MCP)

```text
# See what's downloading and confirm SABnzbd is up
mcp__rustarr__sabnzbd(action="download_queue")
mcp__rustarr__sabnzbd(action="service_status")

# Add an NZB by URL (writes need confirm=true)
mcp__rustarr__sabnzbd(action="download_add",
  url="https://indexer.example/get.php?guid=...", confirm=true)

# Pause everything, then resume everything
mcp__rustarr__sabnzbd(action="download_pause", confirm=true)
mcp__rustarr__sabnzbd(action="download_resume", confirm=true)

# Remove one download by its nzo_id, keeping files on disk
mcp__rustarr__sabnzbd(action="download_remove",
  id="SABnzbd_nzo_xxxxx", confirm=true)
```

### Fallback (CLI)

```bash
rustarr sabnzbd queue
rustarr sabnzbd add --url "https://indexer.example/get.php?guid=..." --confirm
rustarr sabnzbd pause --confirm                         # pause all
rustarr sabnzbd resume --id SABnzbd_nzo_xxxxx --confirm  # resume one
rustarr sabnzbd remove --id SABnzbd_nzo_xxxxx --delete-files --confirm
```

### Last resort (direct API script)

```bash
./scripts/sab-api.sh queue                       # active queue slots
./scripts/sab-api.sh add "https://indexer.example/get.php?guid=..."
./scripts/sab-api.sh pause                        # pause all
./scripts/sab-api.sh resume-job SABnzbd_nzo_xxxxx # resume one job
./scripts/sab-api.sh delete SABnzbd_nzo_xxxxx --files
./scripts/sab-api.sh status                       # full status
```

## Workflow

When the user asks about Usenet downloads:

1. **"What's downloading?"** → `download_queue` and report the active slots
   (filename, percentage, time left).
2. **"Add this NZB"** → `download_add url="<nzb-url>" confirm=true`. Without
   `confirm` the call is rejected and nothing is queued.
3. **"Pause / resume downloads"** → `download_pause` / `download_resume` with no id
   to act on the whole queue, or `id="<nzo_id>"` to target one download.
4. **"Remove that download"** → find its **nzo_id** via `download_queue`, ask
   whether to delete files, then `download_remove id="<nzo_id>"
   [delete_files=true] confirm=true`.

Always confirm the target download (filename + nzo_id) with the user before a
remove, especially with `delete_files=true`.

## Notes

- SABnzbd uses the `/api` query API; the curated commands and the script both
  target it.
- SABnzbd identifies downloads by **nzo_id** (exposed as `id` / `--id`);
  qBittorrent identifies torrents by **hash** — don't mix identifiers across the
  two DownloadClient services.
- Omitting `id`/`hash` on pause/resume acts on the **entire queue**; supply one to
  target a single download.
- `download_remove` with `delete_files=true` permanently deletes downloaded data —
  always confirm before running it.

## Reference

For the direct-API layer and deeper endpoint detail:

- **[API Endpoints](./references/api-endpoints.md)** — full endpoint reference
- **[Quick Reference](./references/quick-reference.md)** — copy-paste examples
- **[Troubleshooting](./references/troubleshooting.md)** — auth/connection/errors
- [SABnzbd API docs](https://sabnzbd.org/wiki/advanced/api)
