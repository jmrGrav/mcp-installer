#!/usr/bin/env bash
# tests/test-syntax.sh — bash -n syntax check on all scripts
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

echo "Testing bash syntax..."
while IFS= read -r -d '' f; do
    if bash -n "$f" 2>/dev/null; then
        echo "  OK  $f"
        ((PASS++))
    else
        echo "  FAIL $f" >&2
        bash -n "$f" 2>&1 | sed 's/^/       /' >&2
        ((FAIL++))
    fi
done < <(find "$SCRIPT_DIR" -name "*.sh" -not -path "*/.git/*" -print0)

echo
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
