# ADR-0008: Build the AI Lab as a Modular Stack Constructor

- **Status:** accepted
- **Date:** 2026-09-28
- **Deciders:** repository owner and maintainers

## Context

The current Compose model starts most platform services together. A small VPS cannot
reliably run n8n, Dify, OpenClaw, observability, vector storage, local models, and their
databases at the same time. Operators need a convenient way to deploy only the products
required for a lab scenario without manually discovering dependencies or editing Compose.

Typical target stacks include:

- n8n, LiteLLM Proxy, and the databases required by those selected services;
- Dify, LiteLLM Proxy, and all required Dify dependencies;
- OpenClaw without Dify or n8n;
- any supported stack with optional Ollama, Qdrant, Langfuse, demo PostgreSQL, or workers.

Traefik remains the mandatory reverse proxy. A selection must be repeatable for upgrades,
validation, backup, diagnostics, and recovery. Disabling a component must not delete its
data or rotate unrelated secrets.

## Decision

Implement a component catalog and selector that combines curated presets with an
interactive checklist and a non-interactive interface.

### Component model

- Traefik has no optional profile and is always deployed.
- Each optional product has a stable Compose profile. All internal services belonging to
  a product share that profile; users select products, not individual implementation
  containers.
- A versioned component catalog is the source of truth for profiles, required and
  optional dependencies, conflicts, resource estimates, secrets, volumes, routes,
  validation checks, backup targets, and upgrade behavior.
- The selector resolves the full dependency closure before Compose runs. Compose
  `depends_on` remains a runtime ordering mechanism, not the compatibility resolver.

Initial component relationships:

| Component | Automatically selected dependencies | Notes |
|-----------|-------------------------------------|-------|
| Traefik | none | Mandatory baseline |
| n8n | none | Uses its existing persistent storage by default |
| LiteLLM Proxy | LiteLLM database | Shared model gateway for compatible clients |
| Dify | Dify API/Web/worker/beat, database, Redis, sandbox, plugin daemon, Qdrant | Qdrant is required while Dify uses it as `VECTOR_STORE` |
| OpenClaw | host prerequisites selected by its operating mode | Rootless sandbox mode requires additional host checks |
| Ollama | none | Optional local-model runtime; never downloaded implicitly |
| Qdrant | none | Optional unless selected as another component's backend |
| Langfuse | Langfuse database | Optional observability |
| FFmpeg worker | n8n | Internal worker, not a public application |
| Demo database | none | Optional shared database for lab projects |

Provider/model compatibility is validated separately from container dependencies.
Selecting LiteLLM does not imply that every subscription, API, or OpenAI-compatible
feature can be routed through it. The catalog records supported integration contracts.

### User interface

The deployment script offers:

1. curated presets for common stacks;
2. a custom checklist that starts from a preset or an empty optional selection;
3. a non-interactive form such as `--preset` or `--components` for automation;
4. a preview showing selected components, automatically added dependencies, resource
   estimates, routes, volumes, and intended changes before deployment.

Initial presets:

| Preset | Selected products |
|--------|-------------------|
| `n8n-cloud` | Traefik, n8n, LiteLLM Proxy and LiteLLM database |
| `dify-cloud` | Traefik, Dify dependency group, Qdrant, LiteLLM Proxy and LiteLLM database |
| `openclaw` | Traefik and OpenClaw |
| `custom` | Traefik plus checklist selections |

Ollama, Langfuse, demo PostgreSQL, and optional workers remain explicit additions unless
a future preset names them. Presets are convenience inputs to the same resolver; they do
not duplicate Compose definitions.

### Deployment behavior

- The resolved selection is saved in a gitignored, machine-readable file and translated
  into `COMPOSE_PROFILES`. Repeated deployment uses the saved selection unless the user
  requests reconfiguration.
- Preflight validates CPU, available RAM, swap, disk, ports, host prerequisites, existing
  data, required secrets, and resolved Compose configuration. Hard minimum failures stop
  deployment; recommended-capacity warnings require explicit confirmation.
- Existing `.env` values are updated incrementally. The selector never reruns the full
  secret generator on an existing server.
- A change preview distinguishes containers to create, recreate, stop, or leave alone.
  Removing a product from the selection stops/removes its containers but preserves
  volumes by default. Data deletion is a separate confirmed operation.
- Validation, backup, diagnostics, and updates consume the same resolved catalog and only
  target selected components.
- The menu must remain idempotent and safe to rerun through SSH or cloud-init. Interactive
  prompts are disabled in non-interactive mode.

## Alternatives Considered

| Option | Pros | Cons |
|--------|------|------|
| Start the complete stack | Simple Compose command | Exceeds small VPS resources and runs unused products |
| Presets only | Easy to support and document | Cannot represent valid user-specific combinations |
| Checklist only | Flexible | Forces users to understand dependencies and compatibility |
| Separate Compose files per preset | Explicit artifacts | Duplicates services and causes version/configuration drift |
| Presets plus checklist backed by one catalog | Convenient and flexible; one dependency resolver | Requires selector, catalog validation, and migration work |

## Consequences

### Positive

- Small VPS deployments run only required services.
- Dependencies and compatibility are validated before mutation.
- Interactive and automated deployments resolve to the same reproducible state.
- Upgrades, backup, diagnostics, and health checks match the selected stack.
- Component removal does not implicitly destroy data or rotate secrets.

### Negative

- Compose profiles and the component catalog must remain synchronized.
- Resource estimates are guidance and require maintenance as versions change.
- LiteLLM introduces another database and operating boundary when selected.
- Migrating an existing all-in-one host requires a preview and preservation of volumes.

### Risks

- Incorrect dependency metadata could produce a stack that resolves but does not work.
- A profile change can orphan running containers unless reconciliation is explicit.
- Overcommitting memory remains possible when the operator accepts warnings.
- Provider compatibility can drift independently from container versions.

Mitigate these risks with catalog schema validation, preset tests, resolved Compose tests,
representative smoke tests, resource checks, and explicit destructive-action approvals.
