# plugins/rustarr — Claude Code instructions

## What this directory is

Multi-platform plugin package for the Rustarr MCP server. Contains manifests for Claude Code, Codex, and Gemini CLI — all pointing at the same MCP connection config and skills.

## File map

| File | Role |
|---|---|
| `.claude-plugin/plugin.json` | Claude Code manifest — identity, hooks, skills, monitors, `userConfig` |
| `.codex-plugin/plugin.json` | Codex manifest — same data + Codex UI fields (`interface`) |
| `gemini-extension.json` | Gemini CLI manifest — uses `settings` array instead of `userConfig` |
| `.mcp.json` | Shared MCP server connection config used by all three platforms |
| `bin/rustarr` | Release binary used by the monitor — populate with `just install` |
| `hooks/hooks.json` | Lifecycle hook definitions: `SessionStart`, `ConfigChange` |
| `monitors/monitors.json` | Background health monitor config (requires Claude Code v2.1.105+) |
| `skills/rustarr/SKILL.md` | Generic MCP-tool documentation + fleet overview (shared by Claude and Codex) |
| `skills/<service>/` | Per-service skills (sonarr, radarr, prowlarr, overseerr, sabnzbd, qbittorrent, plex, jellyfin, tautulli, tracearr): `SKILL.md` + `scripts/` (direct-API fallback) + `references/`. Each documents an MCP -> CLI -> direct-API ladder |

## Versioning rule

**Do not add a `version` field to any manifest.** The marketplace derives version from the git commit SHA. An explicit `version` field causes every push to register as a new version and creates duplicate marketplace entries.

## Updating a manifest

When changing connection config (URL, auth headers), update `.mcp.json` — do not duplicate the values into each manifest separately. All three platforms read `.mcp.json`.

When changing user-configurable settings, update all three manifests: `userConfig` in the Claude and Codex `plugin.json` files, and `settings` in `gemini-extension.json`. Keep field names and descriptions consistent across all three.

## Monitors (Claude Code v2.1.105+)

`monitors/monitors.json` runs `rustarr watch` from `${CLAUDE_PLUGIN_ROOT}/bin/rustarr`. The binary must exist at that path before the plugin is installed. Populate it with:

```bash
just install   # cargo build --release, then copies to plugins/rustarr/bin/rustarr
```

The monitor command uses `${user_config.server_url}` substitution — this is resolved at runtime from the user's plugin settings. Do not hardcode URLs in `monitors.json`.

When adding a new monitor: add an entry to `monitors.json` and reference only `${CLAUDE_PLUGIN_ROOT}/bin/rustarr` or scripts under `${CLAUDE_PLUGIN_ROOT}/scripts/`. Do not reference bare binary names that depend on PATH.

## Updating the skill

`skills/rustarr/SKILL.md` is shared by Claude Code and Codex. Gemini reads it via the `skills` path in `gemini-extension.json`. Edit it once — all platforms see the change.

The three-tier structure must be preserved:
- **Tier 1** (above fold): tool name, quick action table, critical gotchas
- **Tier 2** (middle): full action reference with parameters and response shapes
- **Tier 3** (bottom): workflows, HTTP fallback, error handling

## Updating plugin setup

`hooks/hooks.json` runs `${CLAUDE_PLUGIN_ROOT}/bin/rustarr setup plugin-hook`.
When you add or rename a `userConfig` field, update the binary-owned plugin
setup env mapping in `src/main.rs` / `src/cli/setup.rs` so
`CLAUDE_PLUGIN_OPTION_*` values still map to the correct `RUSTARR_*` variables.

Sensitive fields declared `"sensitive": true` in `plugin.json` are available as env vars in hooks but are **never** substituted into skill content.

## Rustarr-specific package

This directory is the concrete rustarr plugin package. Keep identifiers aligned
with the `rustarr` binary, `RUSTARR_*` environment variables, and the
`skills/rustarr/` skill path. Keep the no-version rule: do not add `"version"`
to any manifest.
