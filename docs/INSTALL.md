# Installation Guide

## Prerequisites

Before running the installer, ensure:

- Linux server with systemd (Ubuntu 22.04+, Debian 12+, Fedora 38+, Rocky/Alma 9+)
- nginx installed and running
- Root access (`sudo bash install.sh`)
- **Hugo MCP only**: Hugo extended >= 0.140 installed ([releases](https://github.com/gohugoio/hugo/releases))
- **Grav MCP only**: Grav CMS already installed, PHP 8.1+
- **Hugo/Grav MCP**: An existing Hugo site or Grav installation
- Python 3.10+ (installed automatically if missing on Debian/RHEL)

## Interactive install

```bash
git clone https://github.com/jmrGrav/mcp-installer
cd mcp-installer
sudo bash install.sh
```

Follow the menu prompts.

## Silent mode (CI / automation)

Set environment variables before running:

### Hugo MCP + OAuth Proxy

```bash
sudo SILENT_MODE=1 \
     DOMAIN=mcp-hugo.example.com \
     HUGO_SITE_PATH=/var/www/hugo-site \
     MCP_PORT=8000 \
     PROXY_DOMAIN=proxy.example.com \
     PROXY_PORT=8083 \
     BACKEND_URL=http://127.0.0.1:8000/mcp \
     BACKEND_HOST=mcp-hugo.example.com \
     BACKEND_TOKEN=your_mcp_token \
     bash install.sh --hugo --oauth
```

### Grav MCP only (api_key mode)

```bash
sudo SILENT_MODE=1 \
     GRAV_PATH=/var/www/grav \
     MCP_API_KEY=your_secret_key_min_32_chars \
     bash install.sh --grav
```

### All components

```bash
sudo SILENT_MODE=1 \
     DOMAIN=mcp-hugo.example.com \
     HUGO_SITE_PATH=/var/www/hugo-site \
     MCP_PORT=8000 \
     GRAV_PATH=/var/www/grav \
     PROXY_DOMAIN=proxy.example.com \
     PROXY_PORT=8083 \
     BACKEND_URL=http://127.0.0.1:8000/mcp \
     BACKEND_HOST=mcp-hugo.example.com \
     bash install.sh --all
```

## Environment variables reference

| Variable | Component | Required | Default | Description |
|----------|-----------|----------|---------|-------------|
| `DOMAIN` | hugo-mcp | yes | — | Public domain for Hugo MCP |
| `HUGO_SITE_PATH` | hugo-mcp | yes | `/var/www/hugo-site` | Path to Hugo site |
| `MCP_PORT` | hugo-mcp | no | `8000` | Internal listen port |
| `MCP_TOKEN` | hugo-mcp | no | generated | Hugo MCP bearer token |
| `CF_TOKEN` | hugo-mcp | no | — | Cloudflare API token for cache purge |
| `CF_ZONE_ID` | hugo-mcp | no | — | Cloudflare zone ID |
| `GRAV_PATH` | grav-mcp | yes | `/var/www/grav` | Path to Grav installation |
| `MCP_API_KEY` | grav-mcp | no | generated | Grav MCP bearer token |
| `PROXY_DOMAIN` | oauth-proxy | yes | — | Public domain for OAuth proxy |
| `PROXY_PORT` | oauth-proxy | no | `8083` | Internal listen port |
| `BACKEND_URL` | oauth-proxy | yes | `http://127.0.0.1:8000/mcp` | Backend MCP internal URL |
| `BACKEND_HOST` | oauth-proxy | yes | `localhost` | Backend Host header |
| `BACKEND_TOKEN` | oauth-proxy | yes | — | Backend MCP token |

## Post-install steps

1. **Configure nginx**: The installer prints a vhost template. Copy it to `/etc/nginx/sites-available/` and enable it:
   ```bash
   ln -s /etc/nginx/sites-available/mcp-hugo.example.com /etc/nginx/sites-enabled/
   nginx -t && systemctl reload nginx
   ```

2. **Configure SSL**: Install a certificate (Let's Encrypt or Cloudflare) and uncomment the SSL lines in the vhost.

3. **Configure Claude.ai**: In the Claude.ai MCP connector settings, enter:
   - **Connector URL**: `https://<proxy-domain>/mcp`
   - **Client ID**: from `/root/.mcp-oauth-proxy-install-summary.txt`
   - **Client Secret**: from `/root/.mcp-oauth-proxy-install-summary.txt`

4. **Verify credentials**: All tokens and credentials are saved to:
   - `/root/.hugo-mcp-install-summary.txt` (chmod 600)
   - `/root/.grav-mcp-install-summary.txt` (chmod 600)
   - `/root/.mcp-oauth-proxy-install-summary.txt` (chmod 600)

## OS-specific notes

### Ubuntu / Debian

Python venv is installed automatically. If `apt-get` fails, run `apt-get update` first.

### Fedora / Rocky / AlmaLinux

`dnf` is used. SELinux may require additional context adjustments for the systemd service paths — run `restorecon -Rv /opt/hugo-mcp` if the service fails to start.
