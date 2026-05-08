#!/usr/bin/env bash
# MCP Installer — entry point
# Usage: sudo bash install.sh [--hugo] [--grav] [--oauth] [--all] [--silent]
# Curl one-liner: curl -sSL https://raw.githubusercontent.com/jmrGrav/mcp-installer/main/install.sh | sudo bash
set -euo pipefail
IFS=$'\n\t'

# ── Détection curl-pipe vs git clone ─────────────────────────────────────────
# Si exécuté via curl ... | bash, BASH_SOURCE[0] est vide ou "/dev/stdin"
SCRIPT_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ "${BASH_SOURCE[0]}" != "/dev/stdin" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

if [[ -z "$SCRIPT_DIR" ]] || [[ ! -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    echo "[INFO] Running via curl-pipe — cloning installer..."
    INSTALLER_REPO="https://github.com/jmrGrav/mcp-installer.git"
    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_DIR"' EXIT
    git clone --depth=1 -q "$INSTALLER_REPO" "$TMP_DIR"
    cd "$TMP_DIR"
    exec bash install.sh "$@"
fi

# ── Chargement des librairies ─────────────────────────────────────────────────
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/prompts.sh
. "$SCRIPT_DIR/lib/prompts.sh"
# shellcheck source=lib/checks.sh
. "$SCRIPT_DIR/lib/checks.sh"

# ── Vérifications initiales ───────────────────────────────────────────────────
require_root
detect_os

banner

# ── Parsing des flags ─────────────────────────────────────────────────────────
SILENT_MODE="${SILENT_MODE:-0}"
FORCE_ROTATE_TOKENS="${FORCE_ROTATE_TOKENS:-0}"
DRY_RUN="${DRY_RUN:-0}"
SKIP_PREFLIGHT="${SKIP_PREFLIGHT:-0}"
INSTALL_GRAV=0
INSTALL_HUGO=0
INSTALL_OAUTH=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --silent)              SILENT_MODE=1 ;;
        --grav)                INSTALL_GRAV=1 ;;
        --hugo)                INSTALL_HUGO=1 ;;
        --oauth)               INSTALL_OAUTH=1 ;;
        --all)                 INSTALL_GRAV=1; INSTALL_HUGO=1; INSTALL_OAUTH=1 ;;
        --force-rotate-tokens) FORCE_ROTATE_TOKENS=1 ;;
        --dry-run)             DRY_RUN=1 ;;
        --skip-preflight)      SKIP_PREFLIGHT=1 ;;
        --help|-h)             print_usage; exit 0 ;;
        *) log_warn "Unknown flag: $1 (ignored)" ;;
    esac
    shift
done

# ── Mode interactif si rien de spécifié ──────────────────────────────────────
if [[ "$SILENT_MODE" == "0" ]] && [[ "$INSTALL_GRAV$INSTALL_HUGO$INSTALL_OAUTH" == "000" ]]; then
    show_interactive_menu
fi

# ── Logique de dépendances ────────────────────────────────────────────────────
if [[ "$INSTALL_HUGO" == "1" || "$INSTALL_GRAV" == "1" ]] && [[ "$INSTALL_OAUTH" == "0" ]]; then
    echo
    log_info "Hugo MCP and Grav MCP require an OAuth proxy to authenticate Claude.ai."
    if ask_yes_no "Install mcp-oauth-proxy as well?" "y"; then
        INSTALL_OAUTH=1
    fi
fi

# ── Récap avant exécution ─────────────────────────────────────────────────────
echo
log_info "Installation plan:"
[[ "$INSTALL_OAUTH" == "1" ]] && log_info "  · mcp-oauth-proxy  (OAuth 2.1 proxy for Claude.ai)"
[[ "$INSTALL_GRAV"  == "1" ]] && log_info "  · grav-plugin-mcp-server"
[[ "$INSTALL_HUGO"  == "1" ]] && log_info "  · hugo-mcp"
echo

if [[ "$SILENT_MODE" == "0" ]]; then
    ask_yes_no "Continue?" "y" || { echo "Aborted."; exit 0; }
fi

# ── Pre-flight checks ────────────────────────────────────────────────────────
if [[ "$SKIP_PREFLIGHT" != "1" ]]; then
    preflight_errors=0
    [[ "$INSTALL_HUGO"  == "1" ]] && { preflight_hugo_mcp   || preflight_errors=1; }
    [[ "$INSTALL_OAUTH" == "1" ]] && { preflight_oauth_proxy || preflight_errors=1; }
    [[ "$INSTALL_GRAV"  == "1" ]] && { preflight_grav_mcp   || preflight_errors=1; }
    if [[ $preflight_errors -ne 0 ]]; then
        if [[ "$DRY_RUN" == "1" ]]; then
            log_warn "Pre-flight checks failed — continuing in --dry-run mode for analysis"
        else
            log_error "Pre-flight checks failed. Fix the issues above, or use --skip-preflight to bypass."
            exit 1
        fi
    fi
fi

# ── Dry-run short-circuit ─────────────────────────────────────────────────────
if [[ "$DRY_RUN" == "1" ]]; then
    echo
    log_info "[DRY-RUN] Would install:"
    [[ "$INSTALL_OAUTH" == "1" ]] && log_info "[DRY-RUN]   · mcp-oauth-proxy"
    [[ "$INSTALL_GRAV"  == "1" ]] && log_info "[DRY-RUN]   · grav-plugin-mcp-server"
    [[ "$INSTALL_HUGO"  == "1" ]] && log_info "[DRY-RUN]   · hugo-mcp"
    echo
    log_info "[DRY-RUN] No changes made. Remove --dry-run to apply."
    exit 0
fi

# ── Exécution dans l'ordre des dépendances ───────────────────────────────────
export SILENT_MODE SCRIPT_DIR FORCE_ROTATE_TOKENS DRY_RUN SKIP_PREFLIGHT

[[ "$INSTALL_OAUTH" == "1" ]] && bash "$SCRIPT_DIR/modules/install-oauth-proxy.sh"
[[ "$INSTALL_GRAV"  == "1" ]] && bash "$SCRIPT_DIR/modules/install-grav-mcp.sh"
[[ "$INSTALL_HUGO"  == "1" ]] && bash "$SCRIPT_DIR/modules/install-hugo-mcp.sh"

# ── Récap final ───────────────────────────────────────────────────────────────
echo
echo "${BOLD}${GREEN}══ Installation complete ══${NC}"
echo

if [[ "$INSTALL_OAUTH" == "1" ]]; then
    echo "${BOLD}OAuth proxy:${NC}"
    echo "  Credentials: /root/.mcp-oauth-proxy-install-summary.txt"
    echo "  Logs: journalctl -u mcp-oauth-proxy -f"
fi
if [[ "$INSTALL_GRAV" == "1" ]]; then
    echo "${BOLD}Grav MCP:${NC}"
    echo "  Credentials: /root/.grav-mcp-install-summary.txt"
fi
if [[ "$INSTALL_HUGO" == "1" ]]; then
    echo "${BOLD}Hugo MCP:${NC}"
    echo "  Credentials: /root/.hugo-mcp-install-summary.txt"
    echo "  Logs: journalctl -u hugo-mcp -f"
fi

echo
log_info "Next step: configure your nginx vhost(s) using the printed templates above."
log_info "See docs/INSTALL.md for full post-install instructions."
