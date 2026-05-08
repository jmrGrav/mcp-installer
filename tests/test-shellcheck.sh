#!/usr/bin/env bash
# tests/test-shellcheck.sh — shellcheck on all scripts
set -euo pipefail

if ! command -v shellcheck &>/dev/null; then
    echo "shellcheck not installed."
    echo "Install: apt install shellcheck  OR  dnf install ShellCheck"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Running shellcheck..."
# SC1091: not following sourced files (expected — lib/*.sh paths are dynamic)
find "$SCRIPT_DIR" -name "*.sh" -not -path "*/.git/*" \
    -exec shellcheck -e SC1091 {} +

echo "shellcheck passed."
