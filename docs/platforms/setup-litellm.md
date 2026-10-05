# LiteLLM Setup

LiteLLM is an internal model gateway for compatible n8n and Dify clients. The `litellm`
profile builds a small derivative of LiteLLM `v1.103.2` and starts a dedicated PostgreSQL
database. The derivative fixes the Responses **Test Connection** probe's input shape;
the build fails if the upstream probe changes. The Admin UI is
published only on host loopback port 4000 and is not routed through Traefik. PostgreSQL
and model APIs remain private.

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
- the host port is bound to `127.0.0.1` for SSH-tunnel-only administration;
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
ssh -N -L 127.0.0.1:4000:127.0.0.1:4000 lab@<server-ip>
```

Then open `http://127.0.0.1:4000/ui`.

Sign in as `admin` and use `LITELLM_MASTER_KEY` as the bootstrap password. Add provider
credentials under **LLM Credentials**, then add database-backed models under
**Models + Endpoints**. Credentials are encrypted with `LITELLM_SALT_KEY`.

LiteLLM supports ChatGPT Pro/Max subscriptions through the `chatgpt/` provider and OAuth
device flow. Authenticate before adding a `chatgpt/...` model so model creation and
subsequent startups do not wait for an unfinished device flow. In a private SSH session,
run:

```bash
docker exec -it litellm python3 -c \
  'from litellm.llms.chatgpt.authenticator import Authenticator; Authenticator().get_access_token(); print("ChatGPT OAuth stored")'
```

Open the URL printed by LiteLLM and enter the device code yourself. Never paste the code
into chat or logs shared with others. The token and refresh token are stored in the
`litellm-chatgpt-auth` volume through `CHATGPT_TOKEN_DIR`; include that sensitive volume
in backups. After authentication completes, add the `chatgpt/...` model in the Admin UI.

### Add a ChatGPT Subscription model

ChatGPT Subscription is native to the Responses API. Its model mode is therefore
`responses`, even when an n8n client calls `/v1/chat/completions`; LiteLLM bridges that
request to the provider's Responses API.

Use these values under **Models + Endpoints** > **Add Model**:

| Field | Value |
|-------|-------|
| Provider | **ChatGPT Subscription** |
| LiteLLM Model Name(s) | Select an explicit `chatgpt/<model>` when possible, or **All CHATGPT Models (Wildcard)** for discovery |
| Mode for an explicit model | `responses` |
| Mode for the wildcard in LiteLLM `v1.103.2` | Leave it empty because this Admin UI does not expose `responses` in the list |

Do not substitute **Completion - `/completions`**, **Embedding - `/embeddings`**, or
another unrelated mode. Do not select **Chat - `/chat/completions`** merely because n8n
uses that client endpoint: the field describes the provider's native model mode, not the
endpoint used by the client. The wildcard with an empty Mode lets LiteLLM apply the
ChatGPT provider default. For a configuration-managed explicit model, the equivalent is:

```yaml
model_list:
  - model_name: chatgpt/<model>
    model_info:
      mode: responses
    litellm_params:
      model: chatgpt/<model>
```

See the upstream [ChatGPT Subscription provider documentation](https://docs.litellm.ai/docs/providers/chatgpt)
for the native and bridged endpoints.

After adding the wildcard, use **Test Connection** in the Admin UI. The derivative image
passes a list of user messages to the Responses provider, as required by its backend.
The test should report success when authentication and connectivity work. If the server
still runs the original `ghcr.io/berriai/litellm` image, build and recreate only LiteLLM
with `docker compose up -d --build --no-deps litellm` after backing up its database and
OAuth volume. The previous image and database backup provide the rollback path. A
successful connection test does not validate response content or n8n structured output.

LiteLLM `v1.103.2` and the tested `chatgpt/gpt-5.6-terra` route are not a compatible
choice for n8n strict-JSON chains. Requests using `json_schema`, `json_object`, or a
JSON-only prompt can complete upstream with no final output item and fail in LiteLLM with
`Unknown items in responses API response: []`. Use a separately validated API-key model
for workflows that require n8n Structured Output Parser. Do not remove downstream schema
validation or automatic-application safeguards to work around this provider limitation.

n8n and Dify must use `http://litellm:4000/v1` on the private `litellm-clients` network.

Create these stable aliases regardless of the selected upstream provider:

- `lab-chat` for chat/completions clients;
- `lab-embedding` for embedding and RAG clients.

After creating a personal `proxy_admin` account, sign out and confirm that its email and
password work. Then set the following value in the existing server `.env` and recreate
LiteLLM:

```dotenv
LITELLM_DISABLE_ENV_CREDENTIAL_LOGIN=true
```

The default remains `false` so a new installation can bootstrap its first administrator.
After recreation, the shared `admin` plus master-key UI login must return `401`; the
master key remains valid as an API bearer token and recovery credential.

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
salt key before any upgrade. `litellm-chatgpt-auth` stores ChatGPT OAuth and refresh
tokens and is also a sensitive required backup target.
