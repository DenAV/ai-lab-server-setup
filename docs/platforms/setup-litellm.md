# LiteLLM Setup

LiteLLM is an internal-only model gateway for compatible n8n and Dify clients. The
`litellm` profile starts LiteLLM `v1.103.2` and a dedicated PostgreSQL database. The API
and Admin UI bind only to host loopback port 4000; neither service joins
`traefik-public`.

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

Open an SSH tunnel from the operator workstation:

```bash
ssh -L 4000:127.0.0.1:4000 lab@<server-ip>
```

Open `http://127.0.0.1:4000/ui`, sign in as `admin`, and use
`LITELLM_MASTER_KEY` as the bootstrap password. The UI is not publicly routed. Add
provider credentials under **LLM Credentials**, then add database-backed models under
**Models + Endpoints**. Credentials are encrypted with `LITELLM_SALT_KEY`.

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
