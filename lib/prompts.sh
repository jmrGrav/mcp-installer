#!/usr/bin/env bash
# lib/prompts.sh — interactive prompts with SILENT_MODE support

# ask_yes_no <prompt> <default:y|n> → returns 0 (yes) or 1 (no)
ask_yes_no() {
    local prompt="$1"
    local default="${2:-y}"
    local hint
    [[ "$default" == "y" ]] && hint="[Y/n]" || hint="[y/N]"

    if [[ "${SILENT_MODE:-0}" == "1" ]]; then
        [[ "$default" == "y" ]] && return 0 || return 1
    fi

    while true; do
        read -r -p "${YELLOW}?${NC} $prompt $hint: " answer
        answer="${answer:-$default}"
        case "${answer,,}" in
            y|yes) return 0 ;;
            n|no)  return 1 ;;
            *) echo "  Please answer y or n." ;;
        esac
    done
}

# ask_value <var_name> <prompt> [default]
# Sets the variable named $var_name to user input (or env var in silent mode)
ask_value() {
    local var_name="$1"
    local prompt="$2"
    local default="${3:-}"

    if [[ "${SILENT_MODE:-0}" == "1" ]]; then
        local env_val="${!var_name:-}"
        local result="${env_val:-$default}"
        if [[ -z "$result" ]]; then
            log_fatal "SILENT_MODE: required variable '$var_name' is not set and has no default"
        fi
        printf -v "$var_name" '%s' "$result"
        return
    fi

    local display_default=""
    [[ -n "$default" ]] && display_default=" [$default]"

    while true; do
        read -r -p "${BLUE}>${NC} $prompt${display_default}: " answer
        local result="${answer:-$default}"
        if [[ -n "$result" ]]; then
            printf -v "$var_name" '%s' "$result"
            return
        fi
        echo "  This field is required."
    done
}

# ask_secret <var_name> <prompt>
# Like ask_value but does not echo input; in silent mode reads env var
ask_secret() {
    local var_name="$1"
    local prompt="$2"

    if [[ "${SILENT_MODE:-0}" == "1" ]]; then
        local env_val="${!var_name:-}"
        if [[ -z "$env_val" ]]; then
            log_fatal "SILENT_MODE: required secret '$var_name' is not set"
        fi
        printf -v "$var_name" '%s' "$env_val"
        return
    fi

    while true; do
        read -r -s -p "${BLUE}>${NC} $prompt: " answer
        echo
        if [[ -n "$answer" ]]; then
            printf -v "$var_name" '%s' "$answer"
            return
        fi
        echo "  This field is required."
    done
}

# show_interactive_menu — sets INSTALL_GRAV, INSTALL_HUGO, INSTALL_OAUTH in caller's scope
# shellcheck disable=SC2034
show_interactive_menu() {
    echo "${BOLD}What do you want to install?${NC}"
    echo

    ask_yes_no "Hugo MCP server       (FastAPI service for Hugo static sites)" "n" \
        && INSTALL_HUGO=1 || INSTALL_HUGO=0

    ask_yes_no "Grav MCP plugin       (plugin for Grav CMS)" "n" \
        && INSTALL_GRAV=1 || INSTALL_GRAV=0

    ask_yes_no "OAuth 2.1 proxy       (required for Claude.ai authentication)" "n" \
        && INSTALL_OAUTH=1 || INSTALL_OAUTH=0

    if [[ "$INSTALL_HUGO" == "0" && "$INSTALL_GRAV" == "0" && "$INSTALL_OAUTH" == "0" ]]; then
        echo "Nothing selected. Aborted."
        exit 0
    fi
}
