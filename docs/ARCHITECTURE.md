# Architecture

## Stack overview

```
Claude.ai
    │  HTTPS (OAuth 2.1 + PKCE)
    ▼
nginx (TLS termination)
    │  HTTP loopback
    ▼
mcp-oauth-proxy  (port 8083)
    │  HTTP loopback + Bearer token
    ▼
Hugo MCP  (port 8000)           OR       Grav MCP  (/api/mcp via PHP-FPM)
    │  shell exec                                │  Grav router
    ▼                                            ▼
hugo --minify (deploy.sh)               Grav pages/API
    │
    ▼
Hugo public/ (static files served by nginx)
```

## Components

### mcp-oauth-proxy (v2.0.0)

OAuth 2.1 + PKCE proxy. Sits between Claude.ai and the backend MCP server.

- Implements RFC 7591 dynamic client registration
- Implements RFC 9728 OAuth Protected Resource Metadata
- Stores access tokens as SHA-256 hashes (never plaintext)
- Transparent proxy: all MCP requests forwarded verbatim to backend
- No tool schema caching (backend is single source of truth)
- Runs as `mcp-proxy` system user, loopback-only network

### hugo-mcp (v1.7.0)

FastAPI service exposing a Hugo static site as an MCP server.

Tools: `create_page`, `update_page`, `delete_page`, `list_pages`, `get_page`, `rebuild_site`

- Validates frontmatter (size, depth, type, blacklist, conflict detection)
- Deep merge semantics on update (`null` sentinel = delete field)
- Runs `deploy.sh` to rebuild the site after each write
- Runs as `hugo-mcp` system user, which owns the Hugo site directory
- Audit log via `hugo-mcp.audit` logger → journald

### grav-plugin-mcp-server (v1.5.0)

Grav CMS plugin exposing pages as an MCP server.

- Served by Grav's PHP router at `/api/mcp`
- Authentication: `api_key` mode (Bearer token) or `oauth` mode (via proxy)
- Runs as the web server user (`www-data` / `nginx`)

## Security model

All components apply defense-in-depth:

| Layer | Measure |
|-------|---------|
| systemd | `NoNewPrivileges`, `ProtectSystem=strict`, `MemoryDenyWriteExecute`, `CapabilityBoundingSet=` |
| Network | Services bind to `127.0.0.1` only; nginx does TLS termination |
| OAuth | PKCE S256 enforced; tokens stored as SHA-256 hashes |
| Tokens | Generated via `openssl rand` (256-bit entropy); never logged |
| Filesystem | Dedicated system users with minimal permissions |
| Input | Frontmatter validation: size limit (10 KB), depth limit (3), type whitelist, field blacklist |

## Data flow: page creation

1. Claude.ai sends `tools/call create_page` to OAuth proxy (HTTPS)
2. Proxy verifies Bearer token (SHA-256 lookup), forwards to Hugo MCP (HTTP loopback)
3. Hugo MCP validates frontmatter, writes markdown to `content/`
4. Hugo MCP runs `deploy.sh` (`hugo --minify`)
5. Hugo rebuilds `public/`; nginx serves the updated static site

## Multiple MCP backends

You can run multiple OAuth proxy instances for different backends:

```
mcp-oauth-proxy (8083) → Grav MCP
mcp-oauth-proxy (8084) → Hugo MCP     [different service name, different secrets file]
```

Install the OAuth proxy twice with different `PROXY_PORT` and `SERVICE_NAME` values,
pointing to different backends. Use different systemd service unit names to avoid conflicts.
