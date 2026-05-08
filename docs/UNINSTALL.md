# Uninstall Guide

The installer does not include an automated uninstall script. Follow these steps manually.

## Hugo MCP

```bash
# Stop and disable service
systemctl stop hugo-mcp
systemctl disable hugo-mcp
rm /etc/systemd/system/hugo-mcp.service
systemctl daemon-reload

# Remove installation
rm -rf /opt/hugo-mcp

# Remove system user
userdel hugo-mcp

# Remove credentials summary
rm -f /root/.hugo-mcp-install-summary.txt

# Restore Hugo site ownership to your normal user
chown -R <your-user>:<your-user> /var/www/hugo-site
```

## MCP OAuth Proxy

```bash
# Stop and disable service
systemctl stop mcp-oauth-proxy
systemctl disable mcp-oauth-proxy
rm /etc/systemd/system/mcp-oauth-proxy.service
systemctl daemon-reload

# Remove installation and config
rm -rf /opt/mcp-oauth-proxy
rm -rf /etc/mcp-oauth-proxy
rm -rf /var/log/mcp-oauth

# Remove system user
userdel mcp-proxy

# Remove credentials summary
rm -f /root/.mcp-oauth-proxy-install-summary.txt
```

## Grav MCP Plugin

```bash
# Remove plugin
GRAV_PATH=/var/www/grav  # adjust to your path
rm -rf "$GRAV_PATH/user/plugins/mcp-server"
rm -f "$GRAV_PATH/user/config/plugins/mcp-server.yaml"

# Clear Grav cache
sudo -u www-data php "$GRAV_PATH/bin/grav" cache --all

# Remove credentials summary
rm -f /root/.grav-mcp-install-summary.txt
```

## nginx vhosts

Remove or disable the vhost files you added during installation:

```bash
rm /etc/nginx/sites-enabled/mcp-hugo.example.com
rm /etc/nginx/sites-available/mcp-hugo.example.com
nginx -t && systemctl reload nginx
```
