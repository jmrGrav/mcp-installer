#!/usr/bin/env bash
# modules/install-grav-mcp.sh — install grav-plugin-mcp-server
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=../lib/prompts.sh
. "$SCRIPT_DIR/lib/prompts.sh"
# shellcheck source=../lib/checks.sh
. "$SCRIPT_DIR/lib/checks.sh"

GRAV_MCP_VERSION="v1.5.0"
GRAV_MCP_REPO="https://github.com/jmrGrav/grav-plugin-mcp-server.git"

echo
echo "${BOLD}── Grav MCP Plugin ──────────────────────────────────${NC}"

# ── Étape 1 : Prérequis ───────────────────────────────────────────────────────

log_info "Checking prerequisites..."
check_git
check_php 1
check_openssl

# ── Étape 2 : Configuration ───────────────────────────────────────────────────

echo
log_info "Grav MCP configuration:"

ask_value GRAV_PATH "Path to your Grav installation" "${GRAV_PATH:-/var/www/grav}"

check_grav "$GRAV_PATH"

# Détecter l'utilisateur web (propriétaire des fichiers Grav)
GRAV_USER=""
if id www-data &>/dev/null; then
    GRAV_USER="www-data"
elif id nginx &>/dev/null; then
    GRAV_USER="nginx"
elif id apache &>/dev/null; then
    GRAV_USER="apache"
else
    ask_value GRAV_USER "Web server user (owner of Grav files)" "www-data"
fi
log_info "Detected Grav web user: $GRAV_USER"

# API key : préserver si existante (--force-rotate-tokens pour forcer)
MCP_API_KEY="${MCP_API_KEY:-}"
_grav_config="$GRAV_PATH/user/config/plugins/mcp-server.yaml"
if [[ "${FORCE_ROTATE_TOKENS:-0}" != "1" ]] && [[ -f "$_grav_config" ]]; then
    _tok=$(grep "^api_key:" "$_grav_config" 2>/dev/null | sed "s/^api_key: *'*//;s/'*$//" || true)
    [[ -n "$_tok" ]] && MCP_API_KEY="$_tok" && log_info "MCP_API_KEY preserved from existing $_grav_config"
fi
if [[ -z "$MCP_API_KEY" ]]; then
    MCP_API_KEY=$(generate_token 32)
    if [[ "${FORCE_ROTATE_TOKENS:-0}" == "1" ]]; then
        log_warn "MCP_API_KEY rotated (--force-rotate-tokens). Claude.ai connector will need re-authentication."
    else
        log_info "Generated MCP_API_KEY (saved in summary file)"
    fi
fi

# ── Étape 3 : Cloner/mettre à jour le plugin ─────────────────────────────────

PLUGIN_DIR="$GRAV_PATH/user/plugins/mcp-server"
log_info "Installing grav-plugin-mcp-server $GRAV_MCP_VERSION to $PLUGIN_DIR..."

if [[ -d "$PLUGIN_DIR/.git" ]]; then
    log_info "Plugin already exists — updating to $GRAV_MCP_VERSION"
    git -C "$PLUGIN_DIR" fetch --tags -q
    git -C "$PLUGIN_DIR" checkout -q "$GRAV_MCP_VERSION"
else
    backup_if_exists "$PLUGIN_DIR"
    git clone --depth=1 -b "$GRAV_MCP_VERSION" -q "$GRAV_MCP_REPO" "$PLUGIN_DIR"
    log_ok "Cloned grav-plugin-mcp-server $GRAV_MCP_VERSION"
fi

# ── Étape 4 : Config utilisateur Grav ────────────────────────────────────────

CONFIG_DIR="$GRAV_PATH/user/config/plugins"
mkdir -p "$CONFIG_DIR"

CONFIG_FILE="$CONFIG_DIR/mcp-server.yaml"
backup_if_exists "$CONFIG_FILE"

cat > "$CONFIG_FILE" << YAML
enabled: true
auth_mode: api_key
api_key: '$MCP_API_KEY'
YAML

chown "$GRAV_USER":"$GRAV_USER" "$CONFIG_FILE"
chmod 640 "$CONFIG_FILE"
log_ok "Plugin config written to $CONFIG_FILE"

# ── Étape 5 : Permissions sur le plugin ──────────────────────────────────────

chown -R "$GRAV_USER":"$GRAV_USER" "$PLUGIN_DIR"
log_ok "Plugin directory ownership set to $GRAV_USER"

# ── Étape 6 : Vider le cache Grav ────────────────────────────────────────────

log_info "Clearing Grav cache..."
if sudo -u "$GRAV_USER" php "$GRAV_PATH/bin/grav" cache --all 2>/dev/null; then
    log_ok "Grav cache cleared"
else
    log_warn "Could not clear Grav cache automatically."
    log_warn "Run manually: sudo -u $GRAV_USER php $GRAV_PATH/bin/grav cache --all"
fi

# ── Étape 7 : Template nginx ─────────────────────────────────────────────────

echo
echo "${BOLD}── nginx location block (add to your Grav vhost) ──${NC}"
sed \
    -e "s|__GRAV_PATH__|$GRAV_PATH|g" \
    "$SCRIPT_DIR/templates/nginx/grav-mcp.conf.tpl"
echo "${BOLD}────────────────────────────────────────────────────${NC}"
echo
log_info "After adding the location: nginx -t && systemctl reload nginx"

# ── Étape 8 : Récap ──────────────────────────────────────────────────────────

SUMMARY_FILE="/root/.grav-mcp-install-summary.txt"
cat > "$SUMMARY_FILE" << SUMMARY
Grav MCP Plugin — installed $(date -Iseconds)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Version:    $GRAV_MCP_VERSION
Grav path:  $GRAV_PATH
Plugin:     $PLUGIN_DIR
Config:     $CONFIG_FILE
Auth mode:  api_key
Endpoint:   https://<your-grav-domain>/api/mcp

TOKEN (keep secret):
MCP_API_KEY: $MCP_API_KEY
SUMMARY
chmod 600 "$SUMMARY_FILE"

log_ok "Summary saved to $SUMMARY_FILE"
echo "${BOLD}${GREEN}Grav MCP Plugin installed successfully.${NC}"
