# LiteLLM Setup

LiteLLM is an internal model gateway for compatible n8n and Dify clients. The `litellm`
profile starts LiteLLM `v1.103.2` and a dedicated PostgreSQL database. Traefik publishes
an operator-restricted Admin UI at `https://<litellm-subdomain>.<domain>`; model APIs and
PostgreSQL remain private. Host loopback port 4000 remains available for recovery access.

## Configuration

New installations receive generated database, master, and salt keys from
`scripts/generate-env.sh`. On an existing host, do not rerun that script. Append only the
missing values to `.env` and generate each secret separately:

```bash
openssl rand -base64 24 | tr -d '/+=' | head -c 24
```

The master and salt values must start with `sk-`. The salt encrypts provider credentials
stored in PostgreSQL and must remain stable after the first provider is added.

`config/litellm-config.yml` bootstraps infrastructure and security settings only:

- prompt and response logging is disabled;
- database-backed model management is enabled;
- the static model list stays empty to avoid a second source of truth.

## Static Preview

Before starting containers:

```bash
COMPOSE_PROFILES=litellm docker compose config --services
```

The result must contain only `traefik`, `litellm`, and `litellm-db`. For a preset, use the
profile combinations in [Compose Profiles](../operations/compose-profiles.md).

## Admin UI And Providers

Set `LITELLM_SUBDOMAIN` in `.env` and create its public DNS record with Cloudflare proxying
enabled. Before allowing Cloudflare traffic at the origin, create a Cloudflare WAF custom
rule matching the complete LiteLLM hostname with action **Managed Challenge**. The
challenge reduces automated abuse but does not identify a specific user; LiteLLM login
remains the user authentication boundary.

```text
http.host eq "<litellm-subdomain>.<domain>"
```

Set `LITELLM_UI_ALLOWLIST` to the comma-separated IPv4 and IPv6 ranges from Cloudflare's
current official IP list. The default `127.0.0.1/32` intentionally denies all remote
access. Do not copy the documentation ranges below; retrieve and review the current
ranges from `https://www.cloudflare.com/ips/` before deployment:

```bash
LITELLM_UI_ALLOWLIST=<cloudflare-ipv4-cidrs>,<cloudflare-ipv6-cidrs>
```

Then open:

```text
https://<litellm-subdomain>.<domain>/ui
```

Sign in as `admin` and use `LITELLM_MASTER_KEY` as the bootstrap password. Add provider
credentials under **LLM Credentials**, then add database-backed models under
**Models + Endpoints**. Credentials are encrypted with `LITELLM_SALT_KEY`.

The WAF challenge is the automated-traffic boundary, LiteLLM login is the user identity
boundary, and the Traefik allowlist is the direct-origin boundary. Requests that do not
come from a Cloudflare edge address are rejected. Traefik also rejects root,
Swagger/OpenAPI, health, public metadata, model discovery, and the declared
OpenAI-compatible inference routes. Some schema-driven or model test controls in the
Admin UI therefore require the loopback recovery path below. n8n and Dify must use
`http://litellm:4000/v1` on the private `litellm-clients` network instead of the public
hostname.

Use the optional `compose.traefik-cloudflare.yml` DNS-01 overlay when upstream TCP 80 is
closed. Keep Cloudflare SSL/TLS mode at `Full (strict)` after origin certificates are
valid. Do not configure Traefik to trust arbitrary `CF-Connecting-IP` or
`X-Forwarded-For` values: this design validates the direct peer as a Cloudflare edge.

For unrestricted administration or when public routing is unavailable, use the loopback
recovery path:

```bash
ssh -L 4000:127.0.0.1:4000 lab@<server-ip>
```

Then open `http://127.0.0.1:4000/ui`.

Create these public aliases regardless of the selected upstream provider:

- `lab-chat` for chat/completions clients;
- `lab-embedding` for embedding and RAG clients.

After creating a personal `proxy_admin` account and confirming its login, disable the
shared environment credential login as described in the official LiteLLM Admin UI guide.

## Client Credentials

`LITELLM_MASTER_KEY` is administrative and must never be configured in a client. After
the gateway is healthy, use the master key from a trusted operator session to create
separate virtual keys for n8n and Dify, each restricted to `lab-chat` and
`lab-embedding`. Store those virtual keys in the platform credential stores.

The exact client Base URLs and acceptance gates are documented in
[LiteLLM Integration Contracts](../reference/litellm-contracts.md). The contract remains
`declared-not-executed` until provider, client, key-isolation, and redaction tests pass.

## Persistence And Recovery

`litellm-db-data` stores virtual keys, users, teams, and spend records and is classified
as a required backup target. `LITELLM_SALT_KEY` encrypts provider credentials stored in
the database and must not be changed after use. Back up the database and preserve the
salt key before any upgrade.
