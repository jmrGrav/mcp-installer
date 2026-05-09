#!/usr/bin/env bash
# modules/install-hugo-mcp.sh — install hugo-mcp FastAPI service
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=../lib/prompts.sh
. "$SCRIPT_DIR/lib/prompts.sh"
# shellcheck source=../lib/checks.sh
. "$SCRIPT_DIR/lib/checks.sh"

HUGO_MCP_VERSION="v1.7.0"
HUGO_MCP_REPO="https://github.com/jmrGrav/hugo-mcp.git"
INSTALL_DIR="/opt/hugo-mcp"
SERVICE_USER="hugo-mcp"
SERVICE_NAME="hugo-mcp"

echo
echo "${BOLD}── Hugo MCP ────────────────────────────────────────${NC}"

# ── Étape 1 : Prérequis ───────────────────────────────────────────────────────

log_info "Checking prerequisites..."
check_systemd
check_git
check_python3 10
check_python3_venv
check_openssl
check_hugo
check_curl

# ── Étape 2 : Configuration ───────────────────────────────────────────────────

echo
log_info "Hugo MCP configuration:"

ask_value DOMAIN         "Public domain for Hugo MCP (e.g. mcp-hugo.example.com)" "${DOMAIN:-}"
ask_value HUGO_SITE_PATH "Path to your existing Hugo site"                         "${HUGO_SITE_PATH:-/var/www/hugo-site}"
ask_value MCP_PORT       "Listen port (internal, nginx will proxy this)"           "${MCP_PORT:-8000}"

# Token : préserver si existant, générer sinon (--force-rotate-tokens pour forcer la rotation)
MCP_TOKEN="${MCP_TOKEN:-}"
if [[ "${FORCE_ROTATE_TOKENS:-0}" != "1" ]] && [[ -f "$INSTALL_DIR/.env" ]]; then
    _tok=$(grep '^MCP_TOKEN=' "$INSTALL_DIR/.env" 2>/dev/null | cut -d= -f2- | tr -d '"' || true)
    [[ -n "$_tok" ]] && MCP_TOKEN="$_tok" && log_info "MCP_TOKEN preserved from existing $INSTALL_DIR/.env"
fi
if [[ -z "$MCP_TOKEN" ]]; then
    MCP_TOKEN=$(generate_token 32)
    if [[ "${FORCE_ROTATE_TOKENS:-0}" == "1" ]]; then
        log_warn "MCP_TOKEN rotated (--force-rotate-tokens). Claude.ai connector will need re-authentication."
    else
        log_info "MCP_TOKEN generated (saved in summary file)"
    fi
fi

# Cloudflare (optionnel)
CF_TOKEN="${CF_TOKEN:-}"
CF_ZONE_ID="${CF_ZONE_ID:-}"
if [[ "${SILENT_MODE:-0}" == "0" ]]; then
    if ask_yes_no "Configure Cloudflare cache purge?" "n"; then
        ask_secret CF_TOKEN   "Cloudflare API token"
        ask_value  CF_ZONE_ID "Cloudflare zone ID" ""
    fi
fi

check_hugo_site "$HUGO_SITE_PATH"

# ── Étape 3 : User système ────────────────────────────────────────────────────

log_info "Creating system user..."
create_system_user "$SERVICE_USER" "Hugo MCP service"

# ── Étape 4 : Cloner le code source ──────────────────────────────────────────

log_info "Installing hugo-mcp $HUGO_MCP_VERSION to $INSTALL_DIR..."

if [[ -d "$INSTALL_DIR/.git" ]]; then
    log_info "$INSTALL_DIR already exists — updating to $HUGO_MCP_VERSION"
    git -C "$INSTALL_DIR" fetch --tags -q
    git -C "$INSTALL_DIR" checkout -q "$HUGO_MCP_VERSION"
else
    backup_if_exists "$INSTALL_DIR"
    git clone --depth=1 -b "$HUGO_MCP_VERSION" -q "$HUGO_MCP_REPO" "$INSTALL_DIR"
    log_ok "Cloned hugo-mcp $HUGO_MCP_VERSION"
fi

# ── Étape 5 : Virtualenv + dépendances ───────────────────────────────────────

log_info "Creating Python virtualenv..."
python3 -m venv "$INSTALL_DIR/venv"
"$INSTALL_DIR/venv/bin/pip" install --quiet -r "$INSTALL_DIR/requirements.txt"
log_ok "Dependencies installed"

# ── Étape 5b : TLS — certificat EC P-256 auto-signé (C6) ─────────────────────
# Le service uvicorn écoute en HTTPS. Le proxy NUC vérifie ce certificat.

log_info "Generating TLS certificate (EC P-256, self-signed, 10 years)..."
TLS_DIR="$INSTALL_DIR/tls"
mkdir -p "$TLS_DIR"
# Detect primary VM IP for SAN
VM_IP="$(hostname -I | awk '{print $1}')"
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 \
    -keyout "$TLS_DIR/server.key" \
    -out    "$TLS_DIR/server.crt" \
    -days 3650 -nodes \
    -subj "/CN=$VM_IP" \
    -addext "subjectAltName=IP:$VM_IP,IP:127.0.0.1" \
    2>/dev/null
chmod 600 "$TLS_DIR/server.key"
chown -R "$SERVICE_USER":"$SERVICE_USER" "$TLS_DIR"
log_ok "TLS cert generated: $TLS_DIR/server.crt (IP: $VM_IP)"
log_info "Copy $TLS_DIR/server.crt to your proxy host to enable TLS verification."

# ── Étape 5c : Token migration (C2/C5) ───────────────────────────────────────
# Convertit MCP_TOKEN en hash bcrypt dans tokens.json après pip install

# ── Étape 6 : Fichier .env ────────────────────────────────────────────────────

log_info "Writing .env..."

backup_if_exists "$INSTALL_DIR/.env"

sed \
    -e "s|__TOKEN__|$MCP_TOKEN|g" \
    -e "s|__HUGO_SITE__|$HUGO_SITE_PATH|g" \
    -e "s|__BASE_URL__|https://$DOMAIN|g" \
    -e "s|__CF_TOKEN__|${CF_TOKEN}|g" \
    -e "s|__CF_ZONE_ID__|${CF_ZONE_ID}|g" \
    "$SCRIPT_DIR/templates/env/hugo-mcp.env.tpl" > "$INSTALL_DIR/.env"

chmod 640 "$INSTALL_DIR/.env"
chown root:"$SERVICE_USER" "$INSTALL_DIR/.env"
log_ok ".env written"

# ── Étape 6b : Migrer MCP_TOKEN vers tokens.json (bcrypt) ────────────────────
# token_mgr.py migrate lit MCP_TOKEN depuis .env et crée tokens.json (C2/C5)

if [[ -f "$INSTALL_DIR/token_mgr.py" ]]; then
    log_info "Migrating MCP_TOKEN to tokens.json (bcrypt cost-12)..."
    (cd "$INSTALL_DIR" && MCP_TOKEN="$MCP_TOKEN" sudo -u "$SERVICE_USER" \
        "$INSTALL_DIR/venv/bin/python" token_mgr.py migrate 2>/dev/null) \
        && log_ok "tokens.json created" \
        || log_warn "token_mgr.py migrate failed — MCP_TOKEN env fallback still works"
fi

# ── Étape 7 : deploy.sh ───────────────────────────────────────────────────────
# Script appelé par main.py pour rebuild le site Hugo après chaque modification.

DEPLOY_SH="$INSTALL_DIR/deploy.sh"
if [[ ! -f "$DEPLOY_SH" ]]; then
    cat > "$DEPLOY_SH" << DEPLOY
#!/usr/bin/env bash
set -euo pipefail
cd "$HUGO_SITE_PATH"
hugo --minify 2>&1
DEPLOY
    chmod 750 "$DEPLOY_SH"
    chown "$SERVICE_USER":"$SERVICE_USER" "$DEPLOY_SH"
    log_ok "deploy.sh created at $DEPLOY_SH"
fi

# Patcher le DEPLOY_SH path dans .env si main.py le lit depuis .env
# (hugo-mcp v1.7.0 lit DEPLOY_SH depuis .env — fallback /home/jm/deploy.sh)
if grep -q "^DEPLOY_SH=" "$INSTALL_DIR/.env" 2>/dev/null; then
    sed -i "s|^DEPLOY_SH=.*|DEPLOY_SH=$DEPLOY_SH|" "$INSTALL_DIR/.env"
else
    echo "DEPLOY_SH=$DEPLOY_SH" >> "$INSTALL_DIR/.env"
fi

# ── Étape 8 : Permissions FS ─────────────────────────────────────────────────
# CRITIQUE (leçon hotfix 2026-05-07) :
# hugo-mcp doit être OWNER (pas juste groupe) de hugo-site/ pour :
# - chtimes sur public/ (modif timestamps post-build)
# - créer .hugo_build.lock à la racine du site

log_info "Setting filesystem permissions (hugo-mcp must be owner of hugo-site)..."

# Code source : lisible par le groupe hugo-mcp
chown -R root:"$SERVICE_USER" "$INSTALL_DIR"
chmod -R g+rX "$INSTALL_DIR"
chmod 750 "$INSTALL_DIR/deploy.sh"

# Site Hugo : hugo-mcp doit être OWNER complet
# mkdir -p garantit que content/ et public/ existent (site fresh sans premier build)
mkdir -p "$HUGO_SITE_PATH/content" "$HUGO_SITE_PATH/public"
chown "$SERVICE_USER":"$SERVICE_USER" "$HUGO_SITE_PATH"
chown -R "$SERVICE_USER":"$SERVICE_USER" "$HUGO_SITE_PATH/content"
chown -R "$SERVICE_USER":"$SERVICE_USER" "$HUGO_SITE_PATH/public"
if [[ -d "$HUGO_SITE_PATH/resources" ]]; then
    chown -R "$SERVICE_USER":"$SERVICE_USER" "$HUGO_SITE_PATH/resources"
fi

log_ok "Filesystem permissions set"

# ── Étape 9 : Service systemd ─────────────────────────────────────────────────

log_info "Installing systemd service..."

backup_if_exists /etc/systemd/system/hugo-mcp.service

sed \
    -e "s|__USER__|$SERVICE_USER|g" \
    -e "s|__GROUP__|$SERVICE_USER|g" \
    -e "s|__WORK_DIR__|$INSTALL_DIR|g" \
    -e "s|__HUGO_SITE__|$HUGO_SITE_PATH|g" \
    -e "s|__PORT__|$MCP_PORT|g" \
    "$SCRIPT_DIR/templates/systemd/hugo-mcp.service.tpl" > /etc/systemd/system/hugo-mcp.service

systemctl daemon-reload
systemctl enable --now "$SERVICE_NAME"
log_ok "Service $SERVICE_NAME enabled and started"

# ── Étape 10 : Tests de sanité ────────────────────────────────────────────────

log_info "Waiting for service to start..."
sleep 4

if systemctl is-active --quiet "$SERVICE_NAME"; then
    log_ok "Service $SERVICE_NAME is running"
else
    log_error "Service $SERVICE_NAME failed to start."
    log_error "Check logs: journalctl -u $SERVICE_NAME -n 50"
    exit 1
fi

if curl -sf "http://127.0.0.1:$MCP_PORT/healthz" >/dev/null 2>&1; then
    log_ok "Hugo MCP /healthz responds on port $MCP_PORT"
else
    log_warn "Hugo MCP /healthz did not respond — check: journalctl -u $SERVICE_NAME"
fi

# ── Étape 11 : Template nginx ─────────────────────────────────────────────────

echo
echo "${BOLD}── nginx vhost (add to your nginx config) ──${NC}"
sed \
    -e "s|__DOMAIN__|$DOMAIN|g" \
    -e "s|__PORT__|$MCP_PORT|g" \
    "$SCRIPT_DIR/templates/nginx/hugo-mcp.conf.tpl"
echo "${BOLD}────────────────────────────────────────────${NC}"
echo
log_info "After adding the vhost: nginx -t && systemctl reload nginx"

# ── Étape 12 : Récap ──────────────────────────────────────────────────────────

SUMMARY_FILE="/root/.hugo-mcp-install-summary.txt"
cat > "$SUMMARY_FILE" << SUMMARY
Hugo MCP — installed $(date -Iseconds)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Version:    $HUGO_MCP_VERSION
Install:    $INSTALL_DIR
Service:    $SERVICE_NAME.service
Listen:     127.0.0.1:$MCP_PORT
Domain:     https://$DOMAIN
Hugo site:  $HUGO_SITE_PATH
Deploy:     $DEPLOY_SH

TOKENS (keep secret):
MCP_TOKEN:  $MCP_TOKEN
SUMMARY
chmod 600 "$SUMMARY_FILE"

log_ok "Summary saved to $SUMMARY_FILE"
echo "${BOLD}${GREEN}Hugo MCP installed successfully.${NC}"
