# ADR-0001: Use Traefik as Reverse Proxy

- **Status:** accepted
- **Date:** 2026-03-30

## Context

The AI lab stack runs multiple web services (Flowise, n8n, Langfuse) that
need HTTPS access from the internet. We need a reverse proxy that handles
TLS termination and routes traffic to the correct container.

Options: Traefik, Nginx Proxy Manager, Caddy, plain Nginx.

## Decision

Use **Traefik v3** as the reverse proxy.

## Alternatives Considered

| Option | Pros | Cons |
|--------|------|------|
| **Traefik** | Docker-native, auto-discovery via labels, automatic Let's Encrypt, no manual config per service | Steeper learning curve, verbose label syntax |
| Nginx Proxy Manager | Web UI, easy setup | Extra database (SQLite), manual cert management, not IaC-friendly |
| Caddy | Simple config, automatic HTTPS | No Docker auto-discovery, needs manual Caddyfile |
| Nginx | Battle-tested, flexible | Manual cert renewal, manual config per upstream |

## Consequences

### Positive

- Zero-config service discovery — just add Docker labels
- Automatic TLS with Let's Encrypt
- No config files to maintain per service
- Native Docker Compose integration

### Negative

- Label syntax can be verbose
- Debugging routing issues requires understanding Traefik internals
- Dashboard disabled by default (security trade-off)
