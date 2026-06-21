//! Plugin-option ingestion: copy `CLAUDE_PLUGIN_OPTION_*` env vars injected by
//! Claude Code into the `RUSTARR_*` env vars that `Config::load` reads.

/// Mapping from `CLAUDE_PLUGIN_OPTION_<OPTION>` to the `RUSTARR_*` env var name.
///
/// Each `CLAUDE_PLUGIN_OPTION_*` var is injected by Claude Code from the
/// plugin's `userConfig` fields; we copy the non-empty ones into the
/// `RUSTARR_*` env vars that `Config::load` reads.
///
/// When adding or renaming a `userConfig` field in `plugin.json`, update this
/// table to match.
const PLUGIN_OPTION_MAP: &[(&str, &str)] = &[
    ("CLAUDE_PLUGIN_OPTION_API_TOKEN", "RUSTARR_MCP_TOKEN"),
    ("CLAUDE_PLUGIN_OPTION_SERVER_URL", "RUSTARR_SERVER_URL"),
    ("CLAUDE_PLUGIN_OPTION_RUSTARR_SERVICES", "RUSTARR_SERVICES"),
    ("CLAUDE_PLUGIN_OPTION_SONARR_URL", "RUSTARR_SONARR_URL"),
    (
        "CLAUDE_PLUGIN_OPTION_SONARR_API_KEY",
        "RUSTARR_SONARR_API_KEY",
    ),
    ("CLAUDE_PLUGIN_OPTION_RADARR_URL", "RUSTARR_RADARR_URL"),
    (
        "CLAUDE_PLUGIN_OPTION_RADARR_API_KEY",
        "RUSTARR_RADARR_API_KEY",
    ),
    ("CLAUDE_PLUGIN_OPTION_PROWLARR_URL", "RUSTARR_PROWLARR_URL"),
    (
        "CLAUDE_PLUGIN_OPTION_PROWLARR_API_KEY",
        "RUSTARR_PROWLARR_API_KEY",
    ),
    (
        "CLAUDE_PLUGIN_OPTION_OVERSEERR_URL",
        "RUSTARR_OVERSEERR_URL",
    ),
    (
        "CLAUDE_PLUGIN_OPTION_OVERSEERR_API_KEY",
        "RUSTARR_OVERSEERR_API_KEY",
    ),
    (
        "CLAUDE_PLUGIN_OPTION_QBITTORRENT_URL",
        "RUSTARR_QBITTORRENT_URL",
    ),
    (
        "CLAUDE_PLUGIN_OPTION_QBITTORRENT_USERNAME",
        "RUSTARR_QBITTORRENT_USERNAME",
    ),
    (
        "CLAUDE_PLUGIN_OPTION_QBITTORRENT_PASSWORD",
        "RUSTARR_QBITTORRENT_PASSWORD",
    ),
    ("CLAUDE_PLUGIN_OPTION_PLEX_URL", "RUSTARR_PLEX_URL"),
    ("CLAUDE_PLUGIN_OPTION_PLEX_TOKEN", "RUSTARR_PLEX_TOKEN"),
    ("CLAUDE_PLUGIN_OPTION_JELLYFIN_URL", "RUSTARR_JELLYFIN_URL"),
    (
        "CLAUDE_PLUGIN_OPTION_JELLYFIN_API_KEY",
        "RUSTARR_JELLYFIN_API_KEY",
    ),
    ("CLAUDE_PLUGIN_OPTION_SABNZBD_URL", "RUSTARR_SABNZBD_URL"),
    (
        "CLAUDE_PLUGIN_OPTION_SABNZBD_API_KEY",
        "RUSTARR_SABNZBD_API_KEY",
    ),
    ("CLAUDE_PLUGIN_OPTION_TAUTULLI_URL", "RUSTARR_TAUTULLI_URL"),
    (
        "CLAUDE_PLUGIN_OPTION_TAUTULLI_API_KEY",
        "RUSTARR_TAUTULLI_API_KEY",
    ),
    ("CLAUDE_PLUGIN_OPTION_TRACEARR_URL", "RUSTARR_TRACEARR_URL"),
    (
        "CLAUDE_PLUGIN_OPTION_TRACEARR_TOKEN",
        "RUSTARR_TRACEARR_TOKEN",
    ),
    ("CLAUDE_PLUGIN_OPTION_AUTH_MODE", "RUSTARR_MCP_AUTH_MODE"),
    ("CLAUDE_PLUGIN_OPTION_NO_AUTH", "RUSTARR_MCP_NO_AUTH"),
    ("CLAUDE_PLUGIN_OPTION_PUBLIC_URL", "RUSTARR_MCP_PUBLIC_URL"),
    (
        "CLAUDE_PLUGIN_OPTION_GOOGLE_CLIENT_ID",
        "RUSTARR_MCP_GOOGLE_CLIENT_ID",
    ),
    (
        "CLAUDE_PLUGIN_OPTION_GOOGLE_CLIENT_SECRET",
        "RUSTARR_MCP_GOOGLE_CLIENT_SECRET",
    ),
    (
        "CLAUDE_PLUGIN_OPTION_AUTH_ADMIN_EMAIL",
        "RUSTARR_MCP_AUTH_ADMIN_EMAIL",
    ),
];

/// Copy `CLAUDE_PLUGIN_OPTION_*` values into the corresponding `RUSTARR_*` env
/// vars so that a subsequent `Config::load` picks them up.
///
/// Must run **before** `Config::load()` (see `main.rs::run_cli`) — config is
/// loaded once up front, so setting these vars later has no effect. Values
/// containing newlines or carriage returns are rejected (skipped), matching the
/// `reject_unsafe_value` guard in the former bash adapter. Empty values are
/// skipped so an unset plugin option never clobbers an existing env value.
pub fn apply_plugin_options() {
    for (option_var, rustarr_var) in PLUGIN_OPTION_MAP {
        let Some(value) = std::env::var_os(option_var) else {
            continue;
        };
        let Some(value) = value.to_str() else {
            continue;
        };
        if value.is_empty() {
            continue;
        }
        if value.contains('\n') || value.contains('\r') {
            eprintln!("rustarr setup: {option_var} must not contain newlines; skipping");
            continue;
        }
        // SAFETY: the binary entrypoint calls this before `Config::load()` and
        // before constructing the Tokio runtime, so no runtime worker can
        // concurrently read environment variables.
        unsafe {
            std::env::set_var(rustarr_var, value);
        }
    }
}

#[cfg(test)]
#[path = "plugin_tests.rs"]
mod tests;
