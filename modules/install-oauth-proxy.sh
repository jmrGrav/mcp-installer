#!/usr/bin/env bash
# modules/install-oauth-proxy.sh — install mcp-oauth-proxy service
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=../lib/prompts.sh
. "$SCRIPT_DIR/lib/prompts.sh"
# shellcheck source=../lib/checks.sh
. "$SCRIPT_DIR/lib/checks.sh"

MCP_OAUTH_VERSION="v2.0.0"
MCP_OAUTH_REPO="https://github.com/jmrGrav/mcp-oauth-proxy.git"
INSTALL_DIR="/opt/mcp-oauth-proxy"
SECRETS_DIR="/etc/mcp-oauth-proxy"
AUDIT_LOG_DIR="/var/log/mcp-oauth"
SERVICE_USER="mcp-proxy"
SERVICE_NAME="mcp-oauth-proxy"

echo
echo "${BOLD}── MCP OAuth Proxy ──────────────────────────────────${NC}"

# ── Étape 1 : Prérequis ───────────────────────────────────────────────────────

log_info "Checking prerequisites..."
check_systemd
check_git
check_python3 10
check_python3_venv
check_openssl
check_curl

# ── Étape 2 : Configuration ───────────────────────────────────────────────────

echo
log_info "MCP OAuth Proxy configuration:"

ask_value PROXY_DOMAIN  "Public domain for OAuth proxy (e.g. mcp.example.com)" "${PROXY_DOMAIN:-}"
ask_value PROXY_PORT    "Listen port (internal, nginx will proxy this)"          "${PROXY_PORT:-8083}"
ask_value BACKEND_URL   "Backend MCP URL (internal)"                             "${BACKEND_URL:-http://127.0.0.1:8000/mcp}"
ask_value BACKEND_HOST  "Backend MCP host header"                                "${BACKEND_HOST:-localhost}"
ask_value BACKEND_TOKEN "Backend MCP token (MCP_TOKEN from hugo-mcp or Grav)"   "${BACKEND_TOKEN:-}"

# Credentials OAuth : préserver si existants (--force-rotate-tokens pour forcer)
CLIENT_ID="${CLIENT_ID:-}"
CLIENT_SECRET="${CLIENT_SECRET:-}"
if [[ "${FORCE_ROTATE_TOKENS:-0}" != "1" ]] && [[ -f "$SECRETS_DIR/secrets.env" ]]; then
    _cid=$(grep '^CLIENT_ID=' "$SECRETS_DIR/secrets.env" 2>/dev/null | cut -d= -f2- | tr -d '"' || true)
    _cs=$(grep '^CLIENT_SECRET=' "$SECRETS_DIR/secrets.env" 2>/dev/null | cut -d= -f2- | tr -d '"' || true)
    if [[ -n "$_cid" ]] && [[ -n "$_cs" ]]; then
        CLIENT_ID="$_cid"; CLIENT_SECRET="$_cs"
        log_info "CLIENT_ID and CLIENT_SECRET preserved from existing $SECRETS_DIR/secrets.env"
    fi
fi
if [[ -z "$CLIENT_ID" ]] || [[ -z "$CLIENT_SECRET" ]]; then
    CLIENT_ID=$(generate_token_base64 16)
    CLIENT_SECRET=$(generate_token 32)
    if [[ "${FORCE_ROTATE_TOKENS:-0}" == "1" ]]; then
        log_warn "CLIENT_ID/SECRET rotated (--force-rotate-tokens). Claude.ai connector will need re-authentication."
    else
        log_info "Generated CLIENT_ID and CLIENT_SECRET (saved in summary file)"
    fi
fi

# ── Étape 3 : User système ────────────────────────────────────────────────────

log_info "Creating system user..."
create_system_user "$SERVICE_USER" "MCP OAuth Proxy service"

# ── Étape 4 : Cloner le code source ──────────────────────────────────────────

log_info "Installing mcp-oauth-proxy $MCP_OAUTH_VERSION to $INSTALL_DIR..."

if [[ -d "$INSTALL_DIR/.git" ]]; then
    log_info "$INSTALL_DIR already exists — updating to $MCP_OAUTH_VERSION"
    git -C "$INSTALL_DIR" fetch --tags -q
    git -C "$INSTALL_DIR" checkout -q "$MCP_OAUTH_VERSION"
else
    backup_if_exists "$INSTALL_DIR"
    git clone --depth=1 -b "$MCP_OAUTH_VERSION" -q "$MCP_OAUTH_REPO" "$INSTALL_DIR"
    log_ok "Cloned mcp-oauth-proxy $MCP_OAUTH_VERSION"
fi

# ── Étape 5 : Virtualenv + dépendances ───────────────────────────────────────

log_info "Creating Python virtualenv..."
python3 -m venv "$INSTALL_DIR/venv"
"$INSTALL_DIR/venv/bin/pip" install --quiet -r "$INSTALL_DIR/requirements.txt"
log_ok "Dependencies installed"

# ── Étape 6 : secrets.env ────────────────────────────────────────────────────

log_info "Writing secrets.env..."
mkdir -p "$SECRETS_DIR"
backup_if_exists "$SECRETS_DIR/secrets.env"

sed \
    -e "s|__CLIENT_ID__|$CLIENT_ID|g" \
    -e "s|__CLIENT_SECRET__|$CLIENT_SECRET|g" \
    -e "s|__BACKEND_TOKEN__|$BACKEND_TOKEN|g" \
    -e "s|__BACKEND_URL__|$BACKEND_URL|g" \
    -e "s|__BACKEND_HOST__|$BACKEND_HOST|g" \
    -e "s|__DOMAIN__|$PROXY_DOMAIN|g" \
    -e "s|__PORT__|$PROXY_PORT|g" \
    "$SCRIPT_DIR/templates/env/oauth-proxy.env.tpl" > "$SECRETS_DIR/secrets.env"

chmod 600 "$SECRETS_DIR/secrets.env"
chown root:root "$SECRETS_DIR/secrets.env"
log_ok "secrets.env written to $SECRETS_DIR/secrets.env"

# ── Étape 7 : Permissions FS ─────────────────────────────────────────────────

log_info "Setting filesystem permissions..."
mkdir -p "$AUDIT_LOG_DIR"
chown -R root:"$SERVICE_USER" "$INSTALL_DIR"
chmod -R g+rX "$INSTALL_DIR"
chown "$SERVICE_USER":"$SERVICE_USER" "$AUDIT_LOG_DIR"
log_ok "Filesystem permissions set"

# ── Étape 8 : Service systemd ─────────────────────────────────────────────────

log_info "Installing systemd service..."
backup_if_exists /etc/systemd/system/"$SERVICE_NAME".service

sed \
    -e "s|__USER__|$SERVICE_USER|g" \
    -e "s|__GROUP__|$SERVICE_USER|g" \
    -e "s|__WORK_DIR__|$INSTALL_DIR|g" \
    -e "s|__SECRETS_FILE__|$SECRETS_DIR/secrets.env|g" \
    -e "s|__AUDIT_LOG_DIR__|$AUDIT_LOG_DIR|g" \
    "$SCRIPT_DIR/templates/systemd/mcp-oauth-proxy.service.tpl" > /etc/systemd/system/"$SERVICE_NAME".service

systemctl daemon-reload
systemctl enable --now "$SERVICE_NAME"
log_ok "Service $SERVICE_NAME enabled and started"

# ── Étape 9 : Tests de sanité ────────────────────────────────────────────────

log_info "Waiting for service to start..."
sleep 4

if systemctl is-active --quiet "$SERVICE_NAME"; then
    log_ok "Service $SERVICE_NAME is running"
else
    log_error "Service $SERVICE_NAME failed to start."
    log_error "Check logs: journalctl -u $SERVICE_NAME -n 50"
    exit 1
fi

if curl -sf "http://127.0.0.1:$PROXY_PORT/.well-known/oauth-authorization-server" >/dev/null 2>&1; then
    log_ok "OAuth proxy responds on port $PROXY_PORT"
else
    log_warn "OAuth proxy did not respond — check: journalctl -u $SERVICE_NAME"
fi

# ── Étape 10 : Template nginx ─────────────────────────────────────────────────

echo
echo "${BOLD}── nginx vhost (add to your nginx config) ──${NC}"
sed \
    -e "s|__DOMAIN__|$PROXY_DOMAIN|g" \
    -e "s|__PORT__|$PROXY_PORT|g" \
    "$SCRIPT_DIR/templates/nginx/oauth-proxy.conf.tpl"
echo "${BOLD}────────────────────────────────────────────${NC}"
echo
log_info "After adding the vhost: nginx -t && systemctl reload nginx"

# ── Étape 11 : Récap ──────────────────────────────────────────────────────────

SUMMARY_FILE="/root/.mcp-oauth-proxy-install-summary.txt"
cat > "$SUMMARY_FILE" << SUMMARY
MCP OAuth Proxy — installed $(date -Iseconds)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Version:        $MCP_OAUTH_VERSION
Install:        $INSTALL_DIR
Service:        $SERVICE_NAME.service
Listen:         127.0.0.1:$PROXY_PORT
Domain:         https://$PROXY_DOMAIN
Backend URL:    $BACKEND_URL
Backend Host:   $BACKEND_HOST

CREDENTIALS (keep secret — use in Claude.ai MCP connector):
CLIENT_ID:      $CLIENT_ID
CLIENT_SECRET:  $CLIENT_SECRET
BACKEND_TOKEN:  $BACKEND_TOKEN
SUMMARY
chmod 600 "$SUMMARY_FILE"

log_ok "Summary saved to $SUMMARY_FILE"
echo "${BOLD}${GREEN}MCP OAuth Proxy installed successfully.${NC}"
