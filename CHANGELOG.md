# Changelog

All notable changes to mcp-installer will be documented in this file.

## [1.2.0] — 2026-05-08

### Fixed
- **Critical idempotence bug** (Bug #2): re-running install.sh no longer regenerates
  MCP tokens, CLIENT_ID/SECRET, or MCP_API_KEY. Existing tokens in `.env` /
  `secrets.env` / `mcp-server.yaml` are preserved by default. This fixes broken
  Claude.ai connectors after re-running the installer.

### Added
- `--force-rotate-tokens` : explicitly regenerate all tokens (warns that existing
  Claude.ai connectors will need re-authentication).
- `--dry-run` : show what would be installed without making any changes.
  Pre-flight checks still run to surface missing dependencies.
- `--skip-preflight` : bypass pre-flight checks (not recommended).
- Pre-flight checks verify that required tools (`hugo`, `nginx`, `python3`,
  `openssl`, `git`, `php`) are present before any module runs.

### Notes
- Recommended upgrade path from v1.1.0: re-run install.sh on existing installations.
  Tokens are preserved automatically — no manual intervention needed.

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
