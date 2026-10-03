# Traefik — Reverse Proxy with Automatic TLS

## Overview

Traefik is a cloud-native reverse proxy that automatically discovers Docker
containers and provisions TLS certificates via Let's Encrypt.

- **Ports:** 80 (HTTP → redirect) and 443 (HTTPS); upstream port 80 is optional with DNS-01
- **Dashboard:** disabled by default (security)
- **TLS:** automatic via selectable Let's Encrypt HTTP-01 or Cloudflare DNS-01
- **Config:** Docker labels on each service

## Prerequisites

- A domain pointing to the server IP (A record)
- Port 443 open in the host and upstream firewalls
- Port 80 open when using the default HTTP-01 mode
- A restricted Cloudflare DNS API token when using the optional DNS-01 overlay

## Configuration

### DNS Records

Point your domain and subdomains to the server:

| Record | Type | Value | Service |
|--------|------|-------|---------|
| `ai.example.com` | A | `<server-ip>` | Base record |
| `dify.example.com` | CNAME | `ai.example.com` | Dify |
| `n8n.example.com` | CNAME | `ai.example.com` | n8n |
| `trace.example.com` | CNAME | `ai.example.com` | Langfuse |

### Environment Variables

In `.env`:

```bash
DOMAIN=example.com           # Your domain
ACME_EMAIL=user@example.com  # Let's Encrypt notifications
TRAEFIK_VERSION=3.6
# Required only by compose.traefik-cloudflare.yml
CLOUDFLARE_DNS_API_TOKEN_FILE=/home/lab/.config/ai-lab/secrets/cloudflare-dns-api-token
```

## How It Works

1. Traefik watches Docker for containers with `traefik.enable=true` label
2. Reads routing rules from container labels (`Host`, `entrypoints`)
3. Automatically requests TLS certificates from Let's Encrypt
4. Routes HTTPS traffic to the correct container
5. HTTP redirects to HTTPS through Traefik or the upstream proxy

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
n8n:
  ports:
    - "5678:5678"
```

Access via `http://<server-ip>:5678`, etc. No TLS in this mode.

## Certificate Management

### Option 1: HTTP-01 (Default)

The base `docker-compose.yml` uses HTTP-01. Select this mode when DNS records point
directly to the origin or a proxy passes `/.well-known/acme-challenge/` to Traefik.
Inbound TCP 80 must reach Traefik through every upstream firewall.

```bash
docker compose -f docker-compose.yml config --quiet
docker compose -f docker-compose.yml up -d --force-recreate traefik
```

If `.env` defines `COMPOSE_FILE`, remove `compose.traefik-cloudflare.yml` from that value
before recreating Traefik. Keep `docker-compose.yml` and any unrelated overlays.

### Option 2: Cloudflare DNS-01

Use `compose.traefik-cloudflare.yml` when Cloudflare hosts the authoritative DNS zone,
records remain proxied, or upstream TCP 80 must stay closed. The overlay keeps the same
`letsencrypt` resolver and certificate storage but replaces HTTP-01 with DNS-01. It does
not remove Traefik's host port 80 listener; the cloud firewall remains responsible for
blocking external TCP 80 in this mode.

Create a Cloudflare API token scoped to one zone with only:

- `Zone / Zone / Read`
- `Zone / DNS / Edit`

Never place the token in Git, `.env`, Compose labels, or chat. Save it directly on the
server without exposing it in shell history:

```bash
TOKEN_FILE=/home/lab/.config/ai-lab/secrets/cloudflare-dns-api-token
install -d -m 700 /home/lab/.config/ai-lab/secrets
test ! -e "${TOKEN_FILE}" || { echo "Token file already exists; refusing to overwrite"; exit 1; }
install -m 600 /dev/null "${TOKEN_FILE}"
read -rsp "Cloudflare DNS API token: " CF_TOKEN && printf '\n'
printf '%s' "${CF_TOKEN}" > "${TOKEN_FILE}"
unset CF_TOKEN
```

Confirm ownership and permissions without printing the token:

```bash
stat -c '%U:%G %a %n' /home/lab/.config/ai-lab/secrets/cloudflare-dns-api-token
```

Expected owner is `lab`, mode is `600`. Add only the path to the existing server `.env`:

```dotenv
CLOUDFLARE_DNS_API_TOKEN_FILE=/home/lab/.config/ai-lab/secrets/cloudflare-dns-api-token
```

Do not rerun `scripts/generate-env.sh` on an existing server. Persist the overlay in the
existing `COMPOSE_FILE` value; preserve other host-specific overlays:

```dotenv
COMPOSE_FILE=docker-compose.yml:compose.traefik-cloudflare.yml
```

Validate before rollout:

```bash
TOKEN_FILE=$(sed -n 's/^CLOUDFLARE_DNS_API_TOKEN_FILE=//p' .env | tail -n 1)
test -n "${TOKEN_FILE}" && test -s "${TOKEN_FILE}"
test "$(stat -c '%a' "${TOKEN_FILE}")" = "600"
docker compose config --quiet
docker compose config | grep -q 'dnschallenge.provider=cloudflare'
docker compose config | grep -qv 'acme.httpchallenge'
```

Stop before recreating Traefik if any command fails. These checks validate only presence
and permissions; they never print the token.

Back up the `traefik-certs` volume, then recreate only Traefik:

```bash
docker compose up -d --force-recreate traefik
docker compose logs --tail=100 traefik
```

Verify the certificate directly at the origin, not through Cloudflare. Repeat for every
active hostname and stop if hostname or chain validation fails, or if less than 30 days
remain:

```bash
HOST=n8n.example.com
ORIGIN_IP=192.0.2.10
openssl s_client -connect "${ORIGIN_IP}:443" -servername "${HOST}" \
  -verify_hostname "${HOST}" -verify_return_error </dev/null
openssl s_client -connect "${ORIGIN_IP}:443" -servername "${HOST}" </dev/null 2>/dev/null \
  | openssl x509 -checkend 2592000 -noout
```

Do not print `docker compose config` into support logs without review: it exposes secret
file paths, although not the token value. With upstream TCP 80 closed, enable Cloudflare
**Always Use HTTPS** so HTTP requests redirect at the edge. After origin certificates are
renewed, use Cloudflare SSL/TLS mode **Full (strict)**.

To return to HTTP-01, first open upstream TCP 80, remove the Cloudflare overlay from
`COMPOSE_FILE`, recreate Traefik, and verify a renewal. The Cloudflare token can then be
revoked and its local file removed.

Do not delete the shared `traefik-certs` volume to force renewal: it contains
certificates for multiple services and deleting it does not fix a failing ACME
challenge.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Certificate not issued | Check DNS and origin reachability: `dig +short n8n.example.com` |
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
