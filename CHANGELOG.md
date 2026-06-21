# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Merged the `arrs` plugin's per-service skills into the rustarr plugin.** Ten
  per-service skills — `sonarr`, `radarr`, `prowlarr`, `overseerr`, `sabnzbd`,
  `qbittorrent`, `plex`, `jellyfin`, `tautulli`, and `tracearr` — now ship under
  `plugins/rustarr/skills/`. Each is rewired onto a three-tier access ladder: the
  rustarr MCP tool first, the `rustarr` CLI as a fallback, and a bundled
  direct-API script (`scripts/`) as a last resort. Each per-service skill ships
  `scripts/`, `references/`, and a Codex `agents/openai.yaml` interface file. The
  fallback scripts read credentials from rustarr's materialized `~/.rustarr/.env`
  (accepting
  `RUSTARR_<SVC>_*` aliases), so they reuse the same `userConfig` as the MCP
  server with no separate credential file. The generic `rustarr` skill now points
  to these per-service skills and stays focused on fleet status.
- **Added SABnzbd, Tautulli, and Tracearr to the plugin `userConfig`.** The Claude
  `plugin.json` and `gemini-extension.json` manifests plus the
  `CLAUDE_PLUGIN_OPTION_* -> RUSTARR_*` setup map now cover `sabnzbd_url` /
  `sabnzbd_api_key`, `tautulli_url` / `tautulli_api_key`, and `tracearr_url` /
  `tracearr_token`, so those services can be configured for a plugin-managed local
  server (and reach the fallback scripts) like the others.

### Security

- **Hardened the `.env` loader against key injection.** `load_dotenv_defaults`
  now only injects keys in rustarr's own namespace (`RUSTARR_*`) plus the
  documented `RUST_LOG`; any other key in a `$RUSTARR_HOME/.env` is skipped with a
  warning instead of being written into the process environment. This prevents a
  writable `.env` from smuggling in process-wide variables such as `PATH`,
  `LD_PRELOAD`, or `SSL_CERT_FILE`. Values containing a null byte are now rejected
  instead of panicking `std::env::set_var`.

### Changed

- **Bounded ArrManager `list` responses for large libraries.** Sonarr/Radarr
  `list` now returns an agent-friendly summary envelope with exact
  quality-profile counts, monitored/missing counts, and a paged `items` slice
  (`limit`, `offset`, `fields`) instead of letting large movie/series libraries
  hit the MCP 40KB response cap.
- **Slimmed ArrManager queue-style reads and runtime-filtered MCP tools.**
  Sonarr/Radarr `wanted`, `queue`, and `history` now trim bulky release/import
  metadata from paged records before MCP serialization, and the RMCP server only
  advertises service-named tools for services configured in the running
  deployment.
- **Bumped to Rust edition 2024** (both the `rustarr` and `xtask` crates). Wrapped
  the now-`unsafe` `std::env::set_var`/`remove_var` calls in `unsafe {}` blocks with
  SAFETY justifications, collapsed nested `if let` into stabilized let-chains, and
  reformatted the tree under the 2024 rustfmt style edition.
- **Wired up the `logging` module.** `main.rs` now initialises dual logging
  (pretty console on stderr + JSON-lines file under `{data_dir}/logs/rustarr.log`)
  via `logging::init` in HTTP-server mode; stdio/CLI modes stay on a stderr-only
  `warn` subscriber so the MCP JSON-RPC stream and CLI output are never corrupted.
  File logging is **best-effort**: if the data dir or log file is unavailable
  (read-only mount, permissions, no `HOME`), the server still starts with
  stderr-only logging instead of aborting. The `logging` module was previously
  dead template scaffolding masked behind `pub`; it is now `pub(crate)` with only
  `init` re-exported as `crate::init_logging` for the binary.
- Extracted launch-mode classification into a unit-tested `run_mode::RunMode`
  (`Serve` / `Stdio` / `Cli`) and centralised data-dir resolution behind
  `config::resolve_data_dir` (shared by `.env` loading and logging setup).
- Fixed all 26 pre-existing `cargo doc` warnings (broken/private/ambiguous
  intra-doc links, a bare URL, an unescaped `<service>`) and added a `docs` CI
  job (`RUSTDOCFLAGS=-D warnings cargo doc`) so rustdoc warnings can't regress.

### Removed

- Dropped the unused `token_limit::truncate_if_needed` (and its tests); only
  `serialize_with_limit` is used, by the MCP response path. `token_limit` is now
  `pub(crate)`.

### Added

- **Stateful live write coverage for every shart service in the mcporter suite.**
  `cargo xtask live --suite mcporter` now builds and runs the current checkout's
  debug `rustarr` binary by default, then exhaustively calls every advertised
  MCP action and validates semantic response/error shapes. The confirmed write
  tail now covers Sonarr/Radarr media lifecycles, Arr/Prowlarr tag
  create-update-delete, Prowlarr indexer tests, Overseerr request
  create/approve/decline cleanup, Plex/Jellyfin scans, SABnzbd/qBittorrent
  add-pause-resume-remove cleanup, Tautulli maintenance writes, Bazarr seeded
  blacklist delete, and Tracearr seeded debug-session delete.
- **Tautulli maintenance commands.** Added confirm-gated write actions
  `stats_refresh_libraries`, `stats_refresh_users`, and
  `stats_delete_image_cache` on both MCP and CLI (`rustarr tautulli
  refresh-libraries|refresh-users|delete-image-cache --confirm`), with parity,
  dispatch, CLI, and app-layer tests.
- **Tracearr bearer-token auth.** Tracearr now uses `Authorization: Bearer ...`
  with `/api/v1` path allowance, which lets the live test stack exercise owner
  debug maintenance endpoints through the generic passthrough safely against
  shart.
- **Curated service-grouped command surface (epic).** rustarr moved from a single
  generic-passthrough tool to a service-grouped, capability-scoped command grammar
  spanning both surfaces. The CLI is now `rustarr <service> <command> [flags]`
  (e.g. `rustarr sonarr list`, `rustarr tautulli activity`,
  `rustarr overseerr request --media-type movie --media-id 603 --confirm`); MCP
  now exposes service-named tools (`sonarr`, `radarr`, `prowlarr`, `overseerr`,
  `tautulli`, `plex`, `tracearr`, `sabnzbd`, `qbittorrent`, `jellyfin`, `bazarr`)
  where the service kind is implicit and action×kind validation in the shared
  dispatch guard ensures an action only runs against compatible kinds. Curated
  commands per capability:
  ArrManager (sonarr/radarr) — reads `quality_profiles, list,
  wanted, queue, history, rootfolders, health` and confirm-gated writes
  `set_quality, search, refresh, monitor, unmonitor, add, delete` (the headline
  `set-quality` does NAME-based bulk quality-profile changes with dry-run preview);
  Indexer (prowlarr) — `indexers, indexer_search, indexer_stats, indexer_test`;
  DownloadClient (sabnzbd/qbittorrent) — `download_queue, download_add,
  download_pause, download_resume, download_remove`; MediaServer (plex/jellyfin) —
  `media_sessions, media_libraries, media_search, media_scan`; Requests (overseerr)
  — `requests, request_search, request_create, request_approve, request_decline`;
  Stats (tautulli) — `stats_activity, stats_history, stats_users, stats_libraries`.
  The architecture is a data-driven **descriptor table**: each capability owns one
  `CommandDescriptor` const slice under `src/actions/commands/<cap>.rs`,
  concatenated at the single `registry::curated_commands()` extension point; schema
  enum/conditionals, help, USAGE, scope, the action×kind guard, and CLI verb tables
  all derive from it, so adding a command is one slice edit, not shotgun surgery.
  Registry action names are globally unique (e.g. `download_queue`, `stats_history`,
  `request_create`) to avoid cross-capability collisions; the CLI exposes short
  friendly verbs (`queue`, `history`, `request`) mapped to those actions per
  service group. Bazarr/Tracearr remain `GenericOnly` — deferred
  to the generic `get`/`post`/`put`/`delete` passthrough with no curated surface.
- Removed unsupported service kinds `lidarr`, `readarr`, `wizarr`, and
  `notifiarr` from the service catalog, capability descriptors, generated MCP
  tool schemas, live-test guard, docs, and shart live environment. The supported
  fleet is now 11 kinds: sonarr, radarr, prowlarr, overseerr, tautulli, plex,
  tracearr, sabnzbd, qbittorrent, jellyfin, and bazarr.
- Mechanical CLI ↔ MCP parity guard (`tests/parity.rs`, Z1). Iterates the curated
  descriptor registry and proves every curated command is reachable on BOTH
  surfaces — present in the generated MCP action enum (`all_action_names()`) AND
  parseable as `rustarr <service> <friendly-verb>` into the matching
  `Command::Curated` — plus a bidirectional check (no registry descriptor lacks a
  CLI verb, no CLI verb maps to a non-existent action), a per-verb capability-match
  check, and the confirm/dry-run contract (`mutates => confirm_required`). The
  CLAUDE.md parity table is now a representative summary; this test is the guard
  against drift. Per-capability friendly-verb tables (`VERBS`) were added to each
  `src/cli/commands/<cap>.rs` as the SSOT consumed by both the parity test and
  USAGE rendering.
- Curated, capability-scoped commands for the Stats capability — Tautulli only (C8): `stats_activity` (current streams: stream count + per-stream user, title, state, progress, slimmed), `stats_history` (watch history, slimmed; optional `--start` offset, `--length` page size, `--user` filter), `stats_users` (slimmed to `user_id, username, plays`), and `stats_libraries` (slimmed to section id/name/type + counts). ALL are `rustarr:read` scope, non-mutating, no confirm — Tautulli is read-only stats. Tautulli has no REST resource surface: every command is a GET on `/api/v2?cmd=NAME[&params]` wrapping its result in `{response:{result, data, message}}`. Each command builds the request through the percent-encoding `query_get` helper (user text like `"x&cmd=delete"` cannot inject a second `cmd`, S6) which also injects the `apikey` exactly ONCE via the shared query-auth path — the app layer never adds `apikey` itself (no double key; the key never lands in `cmd`/path strings that Tautulli access-logs). The `{response}` envelope is unwrapped by a small `unwrap_tautulli` helper that surfaces the upstream `message` as an error when `result != "success"`, else returns `response.data` (slimmed). Registry action names are `stats_`-prefixed because `history` collides with the ArrManager `history` command (action names are globally unique); the CLI maps friendly kebab verbs `rustarr tautulli activity | history [--start N --length N --user NAME] | users | libraries` to those actions. Business logic in `src/app/stats.rs`, descriptors in `src/actions/commands/stats.rs` (registered at the single registry extension point), CLI parse in `src/cli/commands/stats.rs`. Commands appear in the generated schema/help/digest gated to tautulli and are rejected for other kinds (e.g. `stats_activity` on sonarr) with a teaching valid-actions error. New `start`/`length` integer schema param types in `src/mcp/schemas/properties.rs`.

- Curated, capability-scoped commands for the Requests capability — Overseerr only (C7): `requests` (list media requests, slimmed to `id,type,status,media,requestedBy`; optional `--filter pending|approved|available`, `--take`, `--skip`), `request_search` (search titles to request, slimmed; results carry the TMDB id), `request_create` (submit a request with `--media-type movie|tv`, `--media-id` TMDB id, optional `--season N` for TV), `request_approve` (`--id`), and `request_decline` (`--id`). `requests`/`request_search` are `rustarr:read`; `request_create`/`request_approve`/`request_decline` mutate and are `rustarr:write` + confirm-gated. `request_approve`/`request_decline` hit Overseerr's `MANAGE_REQUESTS`-gated endpoints and succeed only with an admin API key (a user-scoped key returns 403) — this is documented in the command help/description. All paths are descriptor-driven (`/api/v1` from `ServiceKind::descriptor()`); the create body shape `{mediaType, mediaId, seasons?}` and list/search slimming live in `src/app/requests.rs`. Registry action names avoid the global ArrManager collisions on `search`/`add` by using `requests` / `request_*` names; CLI maps friendly kebab verbs `rustarr overseerr requests [--filter F --take N --skip N] | request --media-type T --media-id ID [--season N …] --confirm | approve --id N --confirm | decline --id N --confirm | search --query X` to those actions. Descriptors in `src/actions/commands/requests.rs` (registered at the single registry extension point), CLI parse in `src/cli/commands/requests.rs`. Commands appear in the generated schema/help/digest gated to overseerr and are rejected for other kinds (e.g. `requests` on sonarr) with a teaching valid-actions error. New `media_id`/`seasons`/`take`/`skip` schema param types in `src/mcp/schemas/properties.rs`.
- Curated, capability-scoped commands for the MediaServer capability — Plex and Jellyfin (C6): `media_sessions` (active streams, slimmed), `media_libraries` (list libraries, slimmed), `media_search` (search by `query`, slimmed), and `media_scan` (trigger a library refresh). The three reads are `rustarr:read`; `media_scan` mutates and is `rustarr:write` + confirm-gated. The two servers share a verb set but their APIs diverge completely, so the per-server implementation split (`src/app/media_server/{plex,jellyfin}.rs`) is unconditional and dispatch keys on `auth_style` from `KindDescriptor`, never an ad-hoc `match kind`. Plex returns XML by default, so EVERY Plex request negotiates JSON by passing `accept_mime = "application/json"` to the transport's `send_get` (the negotiation lives in transport, not the app — no XML parsing in `media_server`); auth is the `X-Plex-Token` query param and search text reaches Plex through the percent-encoding `query_get` helper (`/library/search?query=`, never `format!`'d, S6); endpoints `/status/sessions`, `/library/sections`, `/library/sections/{id}/refresh` (Plex scan requires `--library`). Jellyfin uses the `Authorization: MediaBrowser Token="…"` header (F2); its search ALWAYS sends `includeItemTypes=Movie,Series,Episode` + `recursive=true` (everything is a `BaseItemDto`, ids are UUID strings) via `GET /Items?searchTerm=`; endpoints `/Sessions`, `/Library/VirtualFolders`, `POST /Library/Refresh` (server-wide). Available on both surfaces — MCP `action=media_sessions service=plex` (registry action names are `media_`-prefixed because action names are globally unique and the ArrManager surface already owns `search`) and CLI friendly kebab verbs `rustarr {plex,jellyfin} sessions | libraries | search --query X | scan [--library ID] --confirm`. Descriptors in `src/actions/commands/media_server.rs` (registered at the single registry extension point), CLI parse in `src/cli/commands/media_server.rs`. Commands appear in the generated schema/help/digest gated to plex+jellyfin and are rejected for other kinds (e.g. `media_sessions` on sonarr) with a teaching valid-actions error.
- Curated, capability-scoped commands for the DownloadClient capability — SABnzbd and qBittorrent (C5): `download_queue` (list active downloads, slimmed), `download_add` (queue a download from a URL/magnet), `download_pause`, `download_resume`, and `download_remove`. `download_queue` is `rustarr:read`; the other four mutate and are `rustarr:write` + confirm-gated. `download_remove` defaults `delete_files` to off (opt-in via `--delete-files` / `delete_files=true`). The two clients share a verb set but their APIs diverge completely, so the per-client implementation split (`src/app/download/{sab,qbit}.rs`) is unconditional and dispatch is driven by `KindDescriptor` (`query_api` flag + `auth_style`), never an ad-hoc `match kind`. SABnzbd uses its `?mode=` query API (`mode=queue|addurl|pause|resume`, `name=delete`+`del_files=1`), authed by the query-string `apikey` with `output=json`, built through the percent-encoding `query_get` helper (never `format!`'d into the path, S6) and the removed `nzo_ids` surfaced so a PARTIAL-failure delete can be verified. qBittorrent uses its `/api/v2` REST API over a dedicated cookie-session client (F2/S1 isolation): reads via GET `/torrents/info`, mutations via form POSTs — and crucially the v5 endpoint names `POST /api/v2/torrents/stop` (pause) and `/api/v2/torrents/start` (resume), NOT the removed v4 `pause`/`resume`. A new `RustarrClient::send_form_post` carries the `application/x-www-form-urlencoded` qBittorrent mutations. Available on both surfaces — MCP `action=download_queue service=qbittorrent` (registry action names are `download_`-prefixed because action names are globally unique and the ArrManager surface already owns `queue` from C1) and CLI friendly kebab verbs `rustarr {sabnzbd,qbittorrent} queue | add --url X --confirm | pause|resume [--id N | --hash H] --confirm | remove (--id N | --hash H) [--delete-files] --confirm`. Descriptors in `src/actions/commands/download.rs` (registered at the single registry extension point), CLI parse in `src/cli/commands/download.rs`. Commands appear in the generated schema/help/digest gated to sabnzbd+qbittorrent and are rejected for other kinds (e.g. `download_queue` on plex) with a teaching valid-actions error.
- Curated, capability-scoped commands for the Indexer capability — Prowlarr only (C4): `indexers` (list, slimmed to `id,name,enable,protocol,priority`), `indexer_search` (manual Newznab-style search, required `query` + optional indexer `ids`), `indexer_stats` (per-indexer query/grab/failure counters from `indexerstats`, slimmed), and `indexer_test` (triggers an indexer health check). The three reads are `rustarr:read`; `indexer_test` is `rustarr:write` + mutating + confirm-gated because it triggers an upstream command. Available on both surfaces — MCP `action=indexers service=prowlarr` (registry action names are `indexer_`-prefixed to avoid colliding with the ArrManager `search` command) and CLI `rustarr prowlarr indexers | search --query X [--id N …] | stats | test [--id N] --confirm` (friendly kebab verbs map to the snake_case actions). All paths are descriptor-driven (`/api/v1` from `ServiceKind::descriptor()`); business logic lives in `src/app/indexer.rs`, descriptors in `src/actions/commands/indexer.rs` (registered at the single registry extension point), CLI parse in `src/cli/commands/indexer.rs`. Commands appear in the generated schema enum/conditionals, help, and capability digest, and are rejected for non-prowlarr kinds (e.g. `indexers` on sonarr) with a teaching valid-actions error.
- Curated, capability-scoped WRITE/intent commands for the ArrManager kinds sonarr and radarr (C2): `set_quality`, `search`, `refresh`, `monitor`, `unmonitor`, `add`, `delete`. All are `rustarr:write` scope, mutating, and confirm-gated. The headline `set_quality` does a NAME-based bulk quality-profile change — resolve `--to` (and optional `--from`) profile names→ids via the C1 resolver, select items (by `--id`/`--title`, by current `--from` profile, or all), then `PUT /api/v3/<res>/editor` with the correct id key per resource (`seriesIds` for sonarr, `movieIds` for radarr) plus `qualityProfileId`. This replaces the original raw `PUT /api/v3/series/editor` workflow. Capability-wide safety contract (S3/AN-4): when `confirm` is absent every write command returns a structured dry-run preview (`would_do`, `target_profile`, `from_profile`, `count`, `sample_titles`) and mutates NOTHING; `confirm=true` applies and returns a concise summary (`{changed, from, to}`) rather than raw editor blobs. A count cap refuses to act on more than 100 items in one call unless `bulk=true` (CLI `--bulk`); `delete` is opt-in for file deletion (`--delete-files`), always confirm-gated and capped. `search`/`refresh` start ASYNC `/command` jobs (case-sensitive typed command-name constants `SeriesSearch`/`MoviesSearch`/`RefreshSeries`/`RefreshMovie`) and do not poll. Available on both surfaces — MCP `action=set_quality service=sonarr from=Ultra-HD to=HD-1080p` and CLI `rustarr sonarr set-quality --from "Ultra-HD" --to "HD-1080p" [--confirm]`. Business logic lives in `src/app/arr/write.rs`; descriptors extend the existing `ARR_COMMANDS` slice in `src/actions/commands/arr.rs`; CLI parse extends `src/cli/commands/arr.rs`. The curated arr `delete` verb now owns `rustarr <arr-service> delete` (the generic passthrough `delete` remains for non-arr kinds). New typed param extractors `i64_arg`/`i64_array_arg`/`string_array_arg` in `src/actions/parse.rs`; `ids`/`title`/`bulk`/`delete_files`/`id` get richer schema types in `src/mcp/schemas/properties.rs`.
- Curated, capability-scoped READ commands for the ArrManager kinds sonarr and radarr (the first real curated commands, establishing the per-capability plug-in pattern that later capability beads follow): `quality_profiles`, `list`, `wanted`, `queue`, `history`, `rootfolders`, `health`. All are `rustarr:read` scope, non-mutating. `list` is slimmed to `id,title,qualityProfileId,monitored,sizeOnDisk,status,added`. Available on both surfaces — MCP `action=list service=sonarr` and CLI `rustarr sonarr list` (kebab-case CLI verbs map to snake_case action names). Business logic lives in `src/app/arr/{read,resolve}.rs`; descriptors in `src/actions/commands/arr.rs`; CLI parse hook in `src/cli/commands/arr.rs`. The registry's curated table is now a runtime concat of per-capability const slices (`actions::registry::curated_commands()`, the single extension point); a `RustarrAction::Curated { name, params }` carrier routes curated names through the shared `execute_service_action` dispatch (and its action×kind guard) on both CLI and MCP. Curated arr commands appear in the generated schema enum/conditionals, help, and capability digest, and are rejected for non-arr kinds (e.g. `list` on plex) with a teaching valid-actions error.
- MCP tool input schema is now fully generated from the action registry + capability map. `src/mcp/schemas.rs` is a thin facade over `src/mcp/schemas/properties.rs` (property set = generic params + curated-command params + `verbose`/`fields`) and `src/mcp/schemas/conditionals.rs` (action→required-params and action→allowed-kind `allOf` fragments). Adding a curated-command descriptor now surfaces it in the enum, properties, conditionals, and help with no schema edits.
- `verbose` (bool) and `fields` (string array) response-verbosity opt-ins on the `rustarr` tool schema; default responses stay slim.
- Action×kind validation enforced in the SHARED dispatch path (`actions::dispatch::validate_action_for_service`, called by `execute_service_action`) so both CLI and MCP reject a curated command run against an incompatible service kind. The `ActionNotValidForKind` error carries the valid-action list. The 7 generic/infra actions remain valid for every kind.
- `integrations` action output now includes per-service `capability` and `available_actions`, supported kinds carry their capability class, and a registry-derived `capability_digest` is added when curated commands exist. The same digest is embedded in the generated tool description and help.
- Help text for the MCP `help` action is generated from the registry (`src/actions/help.rs`), replacing the static `HELP_TEXT` const.
- `token_limit::serialize_with_limit` emits a parseable `{ "truncated": true, "reason", "partial" }` JSON envelope when a response exceeds the budget, instead of appending a notice that broke JSON.
- Startup `warn!` when `AuthPolicy::TrustedGatewayUnscoped` is active with mutating actions registered, documenting that scope checks are bypassed in that mode (`confirm=true` still gates mutations).
- `api_put` and `api_delete` passthrough actions (CLI `rustarr put` / `rustarr delete`, MCP `action=api_put` / `action=api_delete`). Both require `rustarr:write` scope and `confirm=true`, completing HTTP-method coverage so rustarr can perform upstream resource updates (e.g. Sonarr/Radarr `series`/`movie` `editor` bulk edits) and deletions. Empty upstream success bodies now return `{ "ok": true, "status": <code> }` instead of erroring.
- Transport split (`src/rustarr/{auth,helpers}.rs`) and per-service auth driven from the `KindDescriptor` capability table: descriptor-driven path allowlists (with Jellyfin `/Sessions`), `query_get` helper that percent-encodes user text for SABnzbd/Tautulli query APIs, `slim()` field-selection helper, and an optional `accept_mime` on `request_json` for JSON negotiation (Plex).
- Unauthenticated `GET /metrics` Prometheus endpoint exposing request rate / latency / status, prefixed `rustarr` (`axum-prometheus`). Left unauthenticated alongside `/health`, `/ready`, `/status` — firewall it like the other probe routes.

### Changed

- CLI restructured to the `rustarr <service> <command> [flags]` grammar. The generic passthrough verbs are now service-grouped (`rustarr sonarr status`, `rustarr sonarr get --path P`, `rustarr sonarr post|put|delete --path P [--body JSON] --confirm`) instead of taking `--service NAME`. Infra commands (`integrations`, `help`, `doctor`, `watch`, `setup`, `serve`, `mcp`) remain service-less. A new router resolves token1 as either an infra verb or a `ServiceKind`, and USAGE is generated from the action registry + capability map. `--yes` is accepted as an alias for `--confirm`. `src/cli.rs` is split into `src/cli/{command,router,parse,usage}.rs`; the per-capability command-parse hook (`router::parse_capability_command`) is the seam later capability beads extend.

### Fixed

- Curated-command PR-review fixes. `set_quality`/`monitor`/`unmonitor` now report
  the upstream-confirmed `changed` count (from the `*arr` `/editor` response array)
  plus `attempted`, marking `confirmed:false` when the response is not an array,
  instead of fabricating the count from the selection length. `set_quality`/
  `monitor` selection by explicit `ids` now errors on ids with no matching row
  (`no items found for ids: [...] on <service>`) rather than pushing empty-title
  ghost rows. `arr_resource_rows` errors on a non-array upstream response (with a
  body preview) instead of silently coercing to zero rows. qBittorrent
  `pause`/`resume`/`remove` now return a `{submitted, status, note}` envelope (the
  WebUI returns an empty body even when no hash matched) instead of a bare
  coerced `{ok:true}`. Prowlarr `indexer_test` uses the correct endpoints
  (`POST /indexer/testall` for all; `GET /indexer/{id}` then `POST /indexer/test`
  for one) — there is no `/indexer/{id}/test` route. Sonarr search/refresh now
  issues the singular per-item `/command` (one POST per id, aggregated job ids)
  since only Radarr accepts a plural `movieIds` batch. Curated
  commands now enforce their declared `required_params` at the dispatch boundary.
- `rustarr --help` USAGE now renders the friendly capability-local CLI verb
  (`activity`, `request`, `queue`, `set-quality`) for each curated command instead
  of the kebab spelling of its globally-unique registry action name
  (`stats-activity`, `request-create`, `download-queue`). The verb mapping is owned
  by each `src/cli/commands/<cap>.rs` module's `VERBS` table and consumed by
  `src/cli/usage.rs`.

### Security

- qBittorrent now uses a dedicated cookie-store HTTP client; the shared client is cookie-less so the qBittorrent SID can no longer bleed to other services on the same host.
- No `Authorization: Bearer` is sent for Plex (token via `X-Plex-Token` query) or Jellyfin (uses `Authorization: MediaBrowser Token="…"` with `X-Emby-Token` fallback).
- `x-emby-token=` added to the error-body redaction list; error-body redaction now also covers JSON-shaped secrets (`"apiKey":"…"`) and form/query `password=` / `x-api-key=` (previously only some query-string keys were redacted).
- Upstream HTTP clients now set a 10s `connect_timeout` and **disable redirect following** (`redirect::Policy::none()`). A compromised or misconfigured upstream can no longer bounce a credential-bearing request to another host. **Behavioral change:** an upstream that previously relied on a 3xx redirect (e.g. an HTTP→HTTPS or trailing-slash bounce from a reverse proxy) now surfaces as an `UpstreamError::Http` instead of being followed — point `RUSTARR_<NAME>_URL` at the final, non-redirecting URL.
- qBittorrent session caching keyed by upstream origin now re-authenticates and retries once on a `401`/`403`, so a server-side-expired SID self-heals instead of failing every request until the TTL lapses.

### Removed

- Removed the unshipped REST API (`src/api.rs`, `/v1/rustarr`) and the `apps/web` Next.js UI; rustarr is MCP + CLI only.
- Removed obsolete template/demo MCP actions (`elicit_name`, `scaffold_intent`) and their scaffold contract artifacts.

## [0.4.0] — 2026-05-14

### Added

- `.github/workflows/codeql.yml` — CodeQL SAST analysis on push to main and weekly scheduled scan; results surface in the GitHub Security tab.
- `.github/workflows/cargo-deny.yml` — license compliance, duplicate dependency, advisory, and source checks via `cargo-deny`.
- `.github/workflows/msrv.yml` — compiles against the declared `rust-version` to catch MSRV regressions early.

## [0.3.0] — 2026-05-14

### Added

- `src/cli/watch.rs` — `rustarr watch` subcommand for live file-system monitoring.
- `plugins/rustarr/monitors/` — plugin monitor definitions for event-driven automation.
- `plugins/rustarr/gemini-extension.json` — Gemini extension manifest for multi-platform plugin distribution.
- `.github/dependabot.yml` + `.github/workflows/dependabot-auto-merge.yml` — automated dependency updates with auto-merge for minor/patch bumps.
- `scripts/asciicheck.py`, `scripts/check-blob-size.py`, `scripts/check-dependency-updates.sh`, `scripts/check-file-size.sh`, `scripts/check-runtime-current.sh`, `scripts/validate-plugin-layout.sh`, `scripts/blob-size-allowlist.txt` — repository validation and quality scripts.
- `tests/plugin_contract.rs` — plugin contract integration tests.
- `docs/PLUGINS.md` — documentation for the plugin system and distribution model.
- `plugins/README.md`, `plugins/rustarr/README.md`, `plugins/rustarr/CLAUDE.md` — plugin-level documentation and agent guidance.
- `apps/web/README.md`, `xtask/README.md`, `tests/README.md`, `scripts/README.md` — README coverage for every major directory.
- `.claude/` — Claude Code project settings for agent-assisted development.

### Changed

- `plugins/rustarr/hooks/plugin-setup.sh` — significant simplification; reduced from ~500 to ~50 lines by extracting reusable logic and removing duplication.
- `Justfile` — expanded with additional recipes covering plugin validation, script checks, and workflow shortcuts.
- `lefthook.yml` — pre-commit hook additions aligned with new script suite.
- `AGENTS.md`, `CLAUDE.md` — updated agent and AI tooling guidance to reflect current project structure.
- `README.md`, `docs/PATTERNS.md` — documentation refreshed for new scripts and plugin layout.

## [0.2.0] — 2026-05-14

### Changed

- Split `src/mcp.rs` into three focused modules: `src/server.rs` (`AppState`, `AuthPolicy`, `build_auth_layer`), `src/server/routes.rs` (Axum router wiring), and `src/api.rs` (REST API handlers). `src/mcp/` now contains only MCP protocol concerns (tools, schemas, prompts, server handler).
- `mcp/rmcp_server.rs` and `mcp/tools.rs` now import `AppState`/`AuthPolicy` from `crate::server` instead of `super`.
- `allowed_origins` visibility widened from `pub(super)` to `pub` to support cross-module access from `server/routes.rs`.
- Updated `src/lib.rs` and `src/main.rs` to reflect new module layout (`pub mod api`, `pub mod server`).

### Added

- `deny.toml` — `cargo-deny` configuration enforcing license allowlist, banning `openssl`/`openssl-sys`, denying yanked crates, and restricting dependency sources to crates.io and `github.com/jmagar/lab.git`. RUSTSEC-2023-0071 acknowledged with rationale.
- `apps/web/CLAUDE.md` — guidance for using the Aurora design system shadcn registry in the Next.js web app: install commands, token conventions, full component catalog, and usage rules.
- `.git/hooks/pre-commit` — enforces the no-`mod.rs` rule at commit time; blocks any staged `mod.rs` file with a clear error message.
- `docs/PATTERNS.md` updated: §1/§1a module layouts reflect new `server`/`api` structure with all `mod.rs` references removed; §5 auth section headers updated; §45 No mod.rs section now includes the git hook script; §A1/§A2 advanced patterns updated to match actual file locations.

### Removed

- `src/mcp/routes.rs` — moved to `src/server/routes.rs`.
- Several obsolete scripts: `backup.sh`, `check-runtime-current.sh`, `plugin-setup.sh`, `reset-db.sh`, `smoke-test.sh`, `test-check-runtime-current.sh`, `validate-marketplace.sh`.
- `docs/server-json-guide.md` — content superseded by `docs/MCP-REGISTRY-PUBLISH-GUIDE.md`.

## [0.1.0] — 2026-05-13

### Added

- Layered architecture: `RustarrClient` (transport) → `RustarrService` (business logic) → MCP/CLI shims
- Action-based dispatch: single `rustarr` MCP tool with `action` parameter routing
- Both transports: Streamable HTTP (`rustarr serve`) and stdio (`rustarr mcp`)
- Bearer token authentication via `RUSTARR_MCP_TOKEN`
- Google OAuth authentication via `RUSTARR_MCP_AUTH_MODE=oauth` (issues RS256 JWTs)
- Loopback/no-auth mode for local development
- MCP elicitation support (`elicit_name` action, spec 2025-06-18) with graceful fallback
- MCP resources: exposes tool schema at `rustarr://schema/mcp-tool`
- MCP prompts: `quick_start` prompt
- CLI with `greet`, `echo`, and `status` subcommands
- Test helpers: `loopback_state()` and `bearer_state()` for credential-free integration tests
- `AuthPolicy` enum making auth choice explicit at construction time
- CORS, Host header validation, request body size limiting built-in
- `resolve_auth_policy_kind()` — refuses to bind `0.0.0.0` without auth (Pattern §27)
- `default_data_dir()` — detects container vs bare-metal, returns `/data` or `~/.rustarr`
- `entrypoint.sh` — Docker entrypoint with permission setup and privilege drop to UID 1000
- `xtask` crate with `dist`, `ci`, `symlink-docs`, `check-env` commands
- `.config/nextest.toml` — nextest configuration with `default` and `ci` profiles
- `taplo.toml` — TOML formatter configuration
- `lefthook.yml` — minimal pre-commit hooks (diff_check, toml_fmt, env_guard)
- `.github/workflows/ci.yml` — CI: fmt, clippy, nextest, taplo, audit, gitleaks
- `.github/workflows/docker-publish.yml` — multi-platform Docker build + Trivy scan
- `.github/workflows/release.yml` — release binaries for linux/amd64 and linux/arm64
- `config.rustarr.toml` — fully annotated config template
- `.env.rustarr` — documented secrets template
- `CHANGELOG.md` following Keep a Changelog format
- Workspace structure: root crate + `xtask/` member
- `symlink-docs` and `symlink-docs-inline` Justfile recipes
