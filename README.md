# mcp-installer

Automated installer for the [Arleo MCP stack](https://arleo.eu):

- **mcp-oauth-proxy** — OAuth 2.1 + PKCE proxy for Claude.ai
- **grav-plugin-mcp-server** — MCP server exposing Grav CMS pages
- **hugo-mcp** — MCP server exposing Hugo static sites

Compatible with: Ubuntu 22.04+, Debian 12+, Fedora 38+, Rocky/Alma 9+.

## Quick start (curl one-liner)

```bash
curl -sSL https://raw.githubusercontent.com/jmrGrav/mcp-installer/main/install.sh | sudo bash
```

You'll be guided through an interactive menu.

## Quick start (git clone, recommended for review)

```bash
git clone https://github.com/jmrGrav/mcp-installer
cd mcp-installer
sudo bash install.sh
```

## Non-interactive (CI/silent mode)

```bash
sudo SILENT_MODE=1 \
     DOMAIN=mcp.example.com \
     HUGO_SITE_PATH=/var/www/hugo-site \
     MCP_PORT=8000 \
     BACKEND_URL=http://127.0.0.1:8000/mcp \
     BACKEND_HOST=mcp-hugo.example.com \
     BACKEND_TOKEN=your_mcp_token \
     PROXY_DOMAIN=proxy.example.com \
     bash install.sh --hugo --oauth
```

See `docs/INSTALL.md` for the full list of environment variables.

## What it installs

| Component | Version | Install path | Service |
|-----------|---------|-------------|---------|
| hugo-mcp | v1.7.0 | `/opt/hugo-mcp` | `hugo-mcp.service` |
| grav-plugin-mcp-server | v1.5.0 | `<grav>/user/plugins/mcp-server` | (Grav/PHP) |
| mcp-oauth-proxy | v2.0.0 | `/opt/mcp-oauth-proxy` | `mcp-oauth-proxy.service` |

## What it does NOT do

- Install nginx (you must have it already)
- Configure SSL certificates (use certbot or Cloudflare separately)
- Configure DNS records
- Install Hugo or Grav themselves (only their MCP plugins/services)

## Flags

```
--all         Install all three components
--hugo        Install Hugo MCP server
--grav        Install Grav MCP plugin
--oauth       Install OAuth 2.1 proxy
--silent      Non-interactive mode (reads env vars)
--help, -h    Show this help
```

## Security

All services run as dedicated system users with hardened systemd units
(`NoNewPrivileges`, `ProtectSystem=strict`, `MemoryDenyWriteExecute`, etc.).
Tokens are generated via `openssl rand` and saved to root-only summary files.

See `docs/ARCHITECTURE.md` for the full security model.

## Uninstall

See `docs/UNINSTALL.md`.

## License

MIT — Jm Rohmer / [arleo.eu](https://arleo.eu)
