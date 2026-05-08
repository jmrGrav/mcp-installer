# Troubleshooting

## Service fails to start

```bash
journalctl -u hugo-mcp -n 50
journalctl -u mcp-oauth-proxy -n 50
```

Common causes:
- **Python venv missing**: re-run the installer, it is idempotent
- **Port already in use**: `ss -tlnp | grep :8000` — change `MCP_PORT`
- **Permission denied on Hugo site**: ensure `hugo-mcp` is the **owner** of the site directory, not just group member (`chown -R hugo-mcp:hugo-mcp /var/www/hugo-site`)
- **Missing `.env` or `secrets.env`**: verify the file exists and has the expected variables

## Hugo MCP: `/healthz` does not respond

```bash
curl -v http://127.0.0.1:8000/healthz
systemctl status hugo-mcp
```

If the service is active but healthz times out, check that uvicorn is binding to `127.0.0.1` (not `0.0.0.0`) in the service file.

## OAuth Proxy: Claude.ai cannot authenticate

1. Verify the proxy is reachable: `curl -sf https://<proxy-domain>/.well-known/oauth-authorization-server | python3 -m json.tool`
2. Verify the CLIENT_ID and CLIENT_SECRET in Claude.ai match `/root/.mcp-oauth-proxy-install-summary.txt`
3. Check nginx is proxying all required paths: `/.well-known/`, `/authorize`, `/token`, `/register`, `/mcp`
4. Check the nginx SSL certificate is valid: `curl -I https://<proxy-domain>/`

## Grav MCP: 401 Unauthorized

- Verify the token in Claude.ai (or your client) matches `MCP_API_KEY` in `/root/.grav-mcp-install-summary.txt`
- Verify the plugin is enabled: Grav Admin → Plugins → MCP Server → Enabled
- Clear Grav cache: `sudo -u www-data php /var/www/grav/bin/grav cache --all`

## Hugo build fails after page update

The `hugo-mcp` service user runs `deploy.sh` to rebuild the site. Common issues:
- **`.hugo_build.lock` permission denied**: `hugo-mcp` must own the site root (`chown hugo-mcp:hugo-mcp /var/www/hugo-site`)
- **`chtimes` error on `public/`**: same fix — `chown -R hugo-mcp:hugo-mcp /var/www/hugo-site/public`
- **Hugo not in PATH**: the systemd service inherits a minimal PATH. Add `ExecStart=/usr/local/bin/hugo ...` or use the full path in `deploy.sh`

## SELinux (Fedora/Rocky/Alma)

If the service starts but immediately fails with "permission denied" and your OS uses SELinux:

```bash
# Check for AVC denials
ausearch -m avc -ts recent

# Restore default contexts
restorecon -Rv /opt/hugo-mcp
restorecon -Rv /opt/mcp-oauth-proxy

# If still failing, temporarily set permissive to diagnose
setenforce 0
systemctl restart hugo-mcp
# Check logs, then re-enable
setenforce 1
```

## Idempotence: re-running the installer

The installer is idempotent — re-running it on an existing installation:
- Updates the code to the pinned version (`git fetch && git checkout`)
- **Overwrites `.env` / `secrets.env`** (previous file is backed up as `.bak.YYYYMMDD-HHMMSS`)
- **Overwrites the systemd service file** (previous backed up)
- Restarts the service with the new configuration

If you have customized `.env` values (e.g., Cloudflare tokens), save them before re-running.
