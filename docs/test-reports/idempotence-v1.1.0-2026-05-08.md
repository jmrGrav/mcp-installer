# Idempotence test report — mcp-installer v1.1.0

**Date:** 2026-05-08  
**VM:** mcp-test-vm (Ubuntu 24.04, KVM)  
**Snapshot baseline:** `fresh-baseline` (Hugo Extended 0.147.0, nginx, minimal Hugo site at `/home/jm/hugo-site`)  
**Components tested:** Hugo MCP + OAuth proxy (Grav skipped)

---

## Run 1 — Fresh install

**Method:** `expect` script driving `ssh -t`, interactive mode (y/n menus)  
**Inputs:** Hugo y · Grav n · OAuth y · domain `mcp-hugo.test.local` / `mcp-proxy.test.local` · ports 8000/8083

| Check | Result |
|-------|--------|
| Installer completed without error | PASS |
| `hugo-mcp.service` active | PASS |
| `mcp-oauth-proxy.service` active | PASS |
| `GET /healthz` → `{"status":"ok"}` on port 8000 | PASS |
| OAuth proxy `.well-known` responds on port 8083 | PASS |
| `hugo-mcp` user created with nologin shell | PASS |
| `mcp-proxy` user created with nologin shell | PASS |
| `hugo-site/` owned by `hugo-mcp:hugo-mcp` | PASS |
| `hugo-site/content/` owned by `hugo-mcp:hugo-mcp` | PASS |
| `hugo-site/public/` owned by `hugo-mcp:hugo-mcp` | PASS |

**Bug fixed:** `mkdir -p content/ public/` before `chown` — no crash on fresh site.

---

## Run 2 — Idempotence (re-run on same VM)

**Method:** Same `expect` script, same answers, no snapshot revert.

| Check | Result | Note |
|-------|--------|------|
| Installer completed without error | PASS | |
| `hugo-mcp.service` active after restart | PASS | |
| `mcp-oauth-proxy.service` active after restart | PASS | |
| `/healthz` responds on port 8000 | PASS | |
| OAuth proxy responds on port 8083 | PASS | |
| User `hugo-mcp` not re-created (`already exists, skipping`) | PASS | |
| User `mcp-proxy` not re-created (`already exists, skipping`) | PASS | |
| Old `.env` backed up before overwrite (`.env.bak.YYYYMMDD-HHMMSS`) | PASS | |
| Old `secrets.env` backed up before overwrite | PASS | |
| Old systemd units backed up before overwrite | PASS | |
| Git repos updated (`already exists — updating to vX.Y.Z`) | PASS | |

### Known issue — Bug #2: token regeneration on re-run

Both modules regenerate their tokens on every run in interactive mode:

- `install-hugo-mcp.sh`: always calls `MCP_TOKEN=$(generate_token 32)` — does not check existing `.env`
- `install-oauth-proxy.sh`: always calls `generate_token_base64` for `CLIENT_ID/CLIENT_SECRET`

**Impact:** After a re-run, previously issued tokens are invalid. Clients connected with the old token must re-authenticate. This does not break the install itself (services restart with the new token) but breaks continuity for production deployments.

**Scope:** Interactive mode only. `--silent` mode honours pre-set env vars.

**Planned fix:** Check for existing `.env` / `secrets.env` and skip token regeneration if file already present; offer `--force-rotate-tokens` flag to explicitly rotate.

---

## Summary

v1.1.0 passes idempotence testing with one known issue (Bug #2, non-blocking for the installer itself). The v1.1.0 menu rework (3 independent y/n questions) works correctly end-to-end via both interactive and expect-driven flows.
