# Idempotence test report — mcp-installer v1.2.0

**Date:** 2026-05-08  
**VM:** mcp-test-vm (Ubuntu 24.04, KVM)  
**Snapshot baseline:** `fresh-baseline` (Hugo Extended 0.147.0, nginx, minimal Hugo site at `/home/jm/hugo-site`)  
**Components tested:** Hugo MCP + OAuth proxy

---

## Test 1 — Pre-flight : outil manquant → abort

**Setup:** Hugo binary removed (`mv /usr/local/bin/hugo /usr/local/bin/hugo.bak`)  
**Command:** `install.sh --hugo --silent`

| Check | Result |
|-------|--------|
| `[ERROR] pre-flight: 'hugo' not found` logged | PASS |
| `[ERROR] Pre-flight checks failed. Fix the issues above...` logged | PASS |
| Installer aborts (exit 1) | PASS |
| No files created in `/opt/hugo-mcp` | PASS |

**Test 1 ✅**

---

## Test 2 — Dry-run : aucun changement appliqué

**Command:** `install.sh --hugo --oauth --dry-run`

| Check | Result |
|-------|--------|
| `[DRY-RUN] Would install: mcp-oauth-proxy` logged | PASS |
| `[DRY-RUN] Would install: hugo-mcp` logged | PASS |
| `[DRY-RUN] No changes made.` logged | PASS |
| `/opt/hugo-mcp` not created | PASS |
| `/opt/mcp-oauth-proxy` not created | PASS |

**Test 2 ✅**

---

## Test 3 — Fresh install (Run 1)

**Method:** `expect` script, interactive mode, Hugo y · Grav n · OAuth y

| Check | Result |
|-------|--------|
| Installer completed without error | PASS |
| `hugo-mcp.service` active | PASS |
| `mcp-oauth-proxy.service` active | PASS |
| `/healthz` responds on port 8000 | PASS |
| OAuth proxy responds on port 8083 | PASS |
| `MCP_TOKEN` generated and saved in `/opt/hugo-mcp/.env` | PASS |
| `CLIENT_ID` + `CLIENT_SECRET` generated and saved in `/etc/mcp-oauth-proxy/secrets.env` | PASS |

Token captured: `MCP_TOKEN=6a1ace76c680c6e6...` (sha256: `acda56b4...`)

**Test 3 ✅**

---

## Test 4 — Re-run sans flag (tokens préservés)

**Method:** Same `expect` script, Run 2 on same VM (no snapshot revert)

| Check | Result |
|-------|--------|
| `[INFO] CLIENT_ID and CLIENT_SECRET preserved from existing /etc/mcp-oauth-proxy/secrets.env` | PASS |
| `[INFO] MCP_TOKEN preserved from existing /opt/hugo-mcp/.env` | PASS |
| Token identical to Run 1 (sha256: `acda56b4...` = same) | PASS |
| Services active after restart | PASS |
| Old `.env` backed up (`.env.bak.YYYYMMDD-HHMMSS`) | PASS |

**Bug #2 confirmed fixed.** Tokens are preserved on re-run by default.

**Test 4 ✅**

---

## Test 5 — `--force-rotate-tokens` (rotation explicite)

**Command:** `install.sh --hugo --oauth --silent FORCE_ROTATE_TOKENS=1`

| Check | Result |
|-------|--------|
| `[WARN] MCP_TOKEN rotated (--force-rotate-tokens)...` logged | PASS |
| `[WARN] CLIENT_ID/SECRET rotated (--force-rotate-tokens)...` logged | PASS |
| Token CHANGED: `6a1ace76...` → `a0bb83bc...` | PASS |
| Services active after rotation | PASS |

**Test 5 ✅**

---

## Summary

All 5 tests pass. v1.2.0 correctly:
- Detects missing dependencies before install (pre-flight)
- Shows intent without acting (dry-run)
- Preserves tokens on re-run (Bug #2 fixed)
- Rotates tokens on explicit request (--force-rotate-tokens)
