# Traefik — Reverse Proxy with Automatic TLS

## Overview

Traefik is a cloud-native reverse proxy that automatically discovers Docker
containers and provisions TLS certificates via Let's Encrypt.

- **Ports:** 80 (HTTP → redirect), 443 (HTTPS)
- **Dashboard:** disabled by default (security)
- **TLS:** automatic via Let's Encrypt HTTP challenge
- **Config:** Docker labels on each service

## Prerequisites

- A domain pointing to the server IP (A record)
- Ports 80 and 443 open in firewall (done by `setup.sh`)

## Configuration

### DNS Records

Point your domain and subdomains to the server:

| Record | Type | Value | Service |
|--------|------|-------|---------|
| `ai.example.com` | A | `<server-ip>` | Base record |
| `dify.example.com` | CNAME | `ai.example.com` | Dify |
| `flow.example.com` | CNAME | `ai.example.com` | Flowise |
| `n8n.example.com` | CNAME | `ai.example.com` | n8n |
| `trace.example.com` | CNAME | `ai.example.com` | Langfuse |

### Environment Variables

In `.env`:

```bash
DOMAIN=example.com           # Your domain
ACME_EMAIL=user@example.com  # Let's Encrypt notifications
TRAEFIK_VERSION=3.2
```

## How It Works

1. Traefik watches Docker for containers with `traefik.enable=true` label
2. Reads routing rules from container labels (`Host`, `entrypoints`)
3. Automatically requests TLS certificates from Let's Encrypt
4. Routes HTTPS traffic to the correct container
5. HTTP (port 80) redirects to HTTPS automatically

## Service Labels Reference

To expose a service through Traefik, add these labels:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.myapp.rule=Host(`app.${DOMAIN}`)"
  - "traefik.http.routers.myapp.entrypoints=websecure"
  - "traefik.http.routers.myapp.tls.certresolver=letsencrypt"
  - "traefik.http.services.myapp.loadbalancer.server.port=3000"
```

| Label | Purpose |
|-------|---------|
| `traefik.enable=true` | Register this container |
| `routers.NAME.rule` | Routing rule (Host, Path, etc.) |
| `routers.NAME.entrypoints` | `web` (80) or `websecure` (443) |
| `routers.NAME.tls.certresolver` | TLS provider (`letsencrypt`) |
| `services.NAME.loadbalancer.server.port` | Container port |

## Enable Dashboard (Development Only)

> **WARNING:** Do not expose the dashboard in production without authentication.

In `docker-compose.yml`, change Traefik command:

```yaml
command:
  - "--api.dashboard=true"
  - "--api.insecure=true"  # Dashboard on port 8080 (no auth!)
ports:
  - "8080:8080"
```

Or with authentication via labels:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.dashboard.rule=Host(`traefik.${DOMAIN}`)"
  - "traefik.http.routers.dashboard.entrypoints=websecure"
  - "traefik.http.routers.dashboard.tls.certresolver=letsencrypt"
  - "traefik.http.routers.dashboard.service=api@internal"
  - "traefik.http.routers.dashboard.middlewares=auth"
  - "traefik.http.middlewares.auth.basicauth.users=admin:$$apr1$$xyz..."
```

Generate password hash:

```bash
htpasswd -nB admin
# Escape $ as $$ in docker-compose labels
```

## Without a Domain (IP Only)

If you don't have a domain, skip Traefik and expose services directly:

```yaml
# In docker-compose.yml, add ports to each service:
flowise:
  ports:
    - "3000:3000"

n8n:
  ports:
    - "5678:5678"
```

Access via `http://<server-ip>:3000`, etc. No TLS in this mode.

## Certificate Management

```bash
# Check certificate status
docker exec traefik cat /certs/acme.json | python3 -m json.tool

# Force certificate renewal (delete and restart)
docker compose stop traefik
docker volume rm ai-lab-server-setup_traefik-certs
docker compose up -d traefik
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Certificate not issued | Check DNS: `dig +short flow.example.com` must resolve |
| 404 on subdomain | Verify container is running: `docker compose ps` |
| 502 Bad Gateway | Container port mismatch — check `loadbalancer.server.port` |
| Rate limit (Let's Encrypt) | Max 5 certs per domain per week — wait or use staging |
| HTTPS redirect loop | Ensure `websecure` entrypoint is used, not `web` |

### Use Let's Encrypt Staging (Testing)

Add to Traefik command:

```yaml
- "--certificatesresolvers.letsencrypt.acme.caserver=https://acme-staging-v02.api.letsencrypt.org/directory"
```

Staging certificates are not trusted by browsers but have no rate limits.
