# Changelog

All notable changes to mcp-installer will be documented in this file.

## [1.1.0] — 2026-05-07

### Changed
- Interactive menu replaced by 3 independent y/n questions (Hugo MCP, Grav MCP, OAuth proxy).
  Any combination is now selectable; nothing is silently excluded.

### Fixed
- `install-hugo-mcp.sh`: `mkdir -p content/ public/` before `chown` — fixes crash on fresh
  Hugo sites where `public/` does not yet exist.

## [1.0.0] — 2026-05-08

Initial release.

### Installs
- hugo-mcp v1.7.0
- grav-plugin-mcp-server v1.5.0
- mcp-oauth-proxy v2.0.0

### Features
- Interactive menu and silent (`--silent`) mode for CI
- OS detection: Ubuntu/Debian (apt) and Fedora/Rocky/Alma (dnf)
- Dedicated system users (`hugo-mcp`, `mcp-proxy`) with no login shell
- Hardened systemd units (NoNewPrivileges, ProtectSystem=strict, MemoryDenyWriteExecute)
- Idempotent: re-running the installer updates existing installations safely
- Automatic token generation via `openssl rand`
- nginx vhost templates printed at end of each module install
- Credentials saved to root-only summary files (`/root/.<service>-install-summary.txt`)
- bash syntax CI via shellcheck GitHub Action
