#!/usr/bin/env bash
# lib/checks.sh — prerequisite checks for each component

check_python3() {
    local min_minor="${1:-10}"  # default: require 3.10+
    if ! command -v python3 &>/dev/null; then
        log_warn "python3 not found — installing..."
        pkg_install python3 python3-venv python3-pip
    fi
    local version
    version=$(python3 -c "import sys; print(sys.version_info.minor)")
    if [[ "$version" -lt "$min_minor" ]]; then
        log_fatal "Python 3.$min_minor+ required. Found: 3.$version"
    fi
    log_ok "python3 $(python3 --version 2>&1 | awk '{print $2}')"
}

check_python3_venv() {
    if ! python3 -m venv --help &>/dev/null; then
        log_warn "python3-venv not found — installing..."
        case "$OS_FAMILY" in
            debian) pkg_install python3-venv python3-pip ;;
            rhel)   pkg_install python3 python3-pip ;;
        esac
    fi
    log_ok "python3-venv"
}

check_git() {
    if ! command -v git &>/dev/null; then
        log_warn "git not found — installing..."
        pkg_install git
    fi
    log_ok "git $(git --version | awk '{print $3}')"
}

check_openssl() {
    if ! command -v openssl &>/dev/null; then
        log_warn "openssl not found — installing..."
        pkg_install openssl
    fi
    log_ok "openssl"
}

check_hugo() {
    if ! command -v hugo &>/dev/null; then
        log_error "hugo not found."
        log_info "Hugo extended is required. Install it from:"
        log_info "  https://github.com/gohugoio/hugo/releases"
        log_info "Example (Linux amd64):"
        log_info "  wget https://github.com/gohugoio/hugo/releases/download/v0.147.0/hugo_extended_0.147.0_linux-amd64.tar.gz"
        log_info "  tar xf hugo_extended_0.147.0_linux-amd64.tar.gz -C /usr/local/bin hugo"
        log_fatal "Please install Hugo extended >= 0.140 and re-run."
    fi
    local hugo_version
    hugo_version=$(hugo version | grep -oP 'v\K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    log_ok "hugo $hugo_version"
}

check_hugo_site() {
    local site_path="$1"
    if [[ ! -d "$site_path" ]]; then
        log_fatal "Hugo site directory not found: $site_path"
    fi
    if [[ ! -f "$site_path/hugo.toml" ]] && \
       [[ ! -f "$site_path/hugo.yaml" ]] && \
       [[ ! -f "$site_path/config.toml" ]] && \
       [[ ! -f "$site_path/config.yaml" ]]; then
        log_fatal "No Hugo config file found in $site_path (expected hugo.toml or config.toml)"
    fi
    log_ok "Hugo site: $site_path"
}

check_php() {
    local min_minor="${1:-1}"  # default: 8.1+
    if ! command -v php &>/dev/null; then
        log_fatal "PHP not found. Grav requires PHP 8.1+. Install PHP before running this installer."
    fi
    local version
    version=$(php -r "echo PHP_VERSION;")
    local major minor
    major=$(echo "$version" | cut -d. -f1)
    minor=$(echo "$version" | cut -d. -f2)
    if [[ "$major" -lt 8 ]] || { [[ "$major" -eq 8 ]] && [[ "$minor" -lt "$min_minor" ]]; }; then
        log_fatal "PHP 8.$min_minor+ required. Found: $version"
    fi
    log_ok "php $version"
}

check_grav() {
    local grav_path="$1"
    if [[ ! -d "$grav_path" ]]; then
        log_fatal "Grav directory not found: $grav_path"
    fi
    if [[ ! -f "$grav_path/bin/grav" ]]; then
        log_fatal "Not a valid Grav installation (bin/grav missing): $grav_path"
    fi
    log_ok "Grav: $grav_path"
}

check_systemd() {
    if ! command -v systemctl &>/dev/null; then
        log_fatal "systemd not found. This installer requires a systemd-based system."
    fi
    log_ok "systemd"
}

check_curl() {
    if ! command -v curl &>/dev/null; then
        log_warn "curl not found — installing..."
        pkg_install curl
    fi
    log_ok "curl"
}

# ── Pre-flight checks ─────────────────────────────────────────────────────────

preflight_hugo_mcp() {
    local errors=0
    for cmd in hugo git python3 openssl; do
        command -v "$cmd" >/dev/null || { log_error "pre-flight: '$cmd' not found"; ((errors++)); }
    done
    [[ $errors -eq 0 ]] && return 0 || return 1
}

preflight_oauth_proxy() {
    local errors=0
    for cmd in python3 openssl git; do
        command -v "$cmd" >/dev/null || { log_error "pre-flight: '$cmd' not found"; ((errors++)); }
    done
    if ! command -v nginx >/dev/null; then
        log_error "pre-flight: 'nginx' not found (required as TLS frontend)"
        ((errors++))
    fi
    [[ $errors -eq 0 ]] && return 0 || return 1
}

preflight_grav_mcp() {
    local errors=0
    command -v php >/dev/null || { log_error "pre-flight: 'php' not found"; ((errors++)); }
    command -v git >/dev/null || { log_error "pre-flight: 'git' not found"; ((errors++)); }
    [[ $errors -eq 0 ]] && return 0 || return 1
}
