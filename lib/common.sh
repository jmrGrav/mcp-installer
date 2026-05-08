#!/usr/bin/env bash
# lib/common.sh — logging, OS detection, token generation, helpers
# shellcheck disable=SC2034

# ── Couleurs ANSI (désactivées si pas de TTY) ────────────────────────────────

if [[ -t 1 ]]; then
    readonly RED=$'\033[0;31m'
    readonly GREEN=$'\033[0;32m'
    readonly YELLOW=$'\033[0;33m'
    readonly BLUE=$'\033[0;34m'
    readonly BOLD=$'\033[1m'
    readonly NC=$'\033[0m'
else
    readonly RED='' GREEN='' YELLOW='' BLUE='' BOLD='' NC=''
fi

# ── Logging ───────────────────────────────────────────────────────────────────

log_info()  { echo "${BLUE}[INFO]${NC} $*"; }
log_ok()    { echo "${GREEN}[OK]${NC}   $*"; }
log_warn()  { echo "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo "${RED}[ERROR]${NC} $*" >&2; }
log_fatal() { log_error "$*"; exit 1; }

# ── Sécurité ─────────────────────────────────────────────────────────────────

require_root() {
    if [[ $EUID -ne 0 ]]; then
        log_fatal "This script must be run as root. Try: sudo bash $0"
    fi
}

# ── Détection OS ──────────────────────────────────────────────────────────────

OS_ID=""
OS_VERSION_ID=""
OS_FAMILY=""

detect_os() {
    if [[ ! -f /etc/os-release ]]; then
        log_fatal "Cannot detect OS (/etc/os-release missing)"
    fi
    # shellcheck source=/dev/null
    . /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_VERSION_ID="${VERSION_ID:-unknown}"
    case "$OS_ID" in
        ubuntu|debian)                      OS_FAMILY="debian" ;;
        fedora|rocky|almalinux|rhel|centos) OS_FAMILY="rhel"   ;;
        *) log_fatal "Unsupported OS: $OS_ID. Supported: Ubuntu, Debian, Fedora, Rocky, AlmaLinux." ;;
    esac
    log_info "Detected: ${BOLD}$OS_ID $OS_VERSION_ID${NC} (family: $OS_FAMILY)"
}

pkg_install() {
    case "$OS_FAMILY" in
        debian) apt-get install -y -qq "$@" ;;
        rhel)   dnf install -y "$@" ;;
    esac
}

pkg_update() {
    case "$OS_FAMILY" in
        debian) apt-get update -qq ;;
        rhel)   dnf check-update -q || true ;;
    esac
}

# ── Génération de tokens ──────────────────────────────────────────────────────

generate_token() {
    local length="${1:-32}"
    openssl rand -hex "$length"
}

generate_token_base64() {
    local length="${1:-32}"
    openssl rand -base64 "$length" | tr -d '=' | tr '/+' '_-'
}

# ── Idempotence helpers ───────────────────────────────────────────────────────

backup_if_exists() {
    local path="$1"
    if [[ -e "$path" ]]; then
        local stamp
        stamp=$(date +%Y%m%d-%H%M%S)
        cp -a "$path" "${path}.bak.${stamp}"
        log_info "Backed up $(basename "$path") → $(basename "$path").bak.$stamp"
    fi
}

create_system_user() {
    local username="$1"
    local comment="${2:-MCP service user}"
    if id "$username" &>/dev/null; then
        log_info "User '$username' already exists, skipping"
    else
        useradd --system --no-create-home --shell /usr/sbin/nologin --comment "$comment" "$username"
        log_ok "Created system user: $username"
    fi
}

# ── Banner ────────────────────────────────────────────────────────────────────

banner() {
    echo
    echo "${BOLD}╔══════════════════════════════════════════╗${NC}"
    echo "${BOLD}║         MCP Installer v1.0.0             ║${NC}"
    echo "${BOLD}║   Hugo MCP · Grav MCP · OAuth Proxy      ║${NC}"
    echo "${BOLD}╚══════════════════════════════════════════╝${NC}"
    echo
}

print_usage() {
    cat <<EOF
Usage: sudo bash install.sh [OPTIONS]

Options:
  --all         Install all three components
  --hugo        Install Hugo MCP server
  --grav        Install Grav MCP plugin
  --oauth       Install OAuth 2.1 proxy
  --silent      Non-interactive mode (reads env vars, see docs/INSTALL.md)
  --help, -h    Show this help

Examples:
  sudo bash install.sh --hugo --oauth
  sudo SILENT_MODE=1 DOMAIN=mcp.example.com bash install.sh --hugo --oauth
EOF
}
