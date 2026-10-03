# Component Catalog

`config/components.yml` is the machine-readable inventory for the modular stack
constructor defined by [ADR-0008](../adr/0008-modular-stack-constructor.md). It records the
current Compose behavior, product profiles, dependency closures, and supported presets.

## Schema

The root contains:

| Field | Contract |
|-------|----------|
| `schema_version` | Catalog format version; currently `1` |
| `compose_files` | Repository Compose files included in drift validation |
| `presets` | Curated component selections with complete required dependency closures |
| `host_prerequisites` | Stable prerequisite IDs and operator-facing descriptions |
| `resource_baseline` | Versioned measurement context, stack totals, and supported host classes |
| `components` | User-selectable product IDs mapped to their current contracts |

Every component records:

| Field | Contract |
|-------|----------|
| `required` | Whether the component is always selected; only Traefik is mandatory |
| `services` | Compose services owned by the component |
| `compose_files` | Files that declare or extend those services |
| `profile` | Shared Compose profile; `null` only for mandatory Traefik |
| `dependencies` | Required automatic selections and optional integrations |
| `conflicts` | Symmetric incompatible component IDs |
| `networks` | Exact union of networks used by owned services |
| `storage` | Exact file/source/target/read-only mounts with backup and sensitivity classification |
| `routes` | Public or loopback endpoints exposed by the component |
| `secrets` | Environment variable names only; never values |
| `health_checks` | Owned services with Compose health checks |
| `resources` | Observed idle memory/CPU metrics, or an explicit unmeasured status |
| `host_prerequisites` | Required IDs plus Compose-file-conditional prerequisite IDs |

`scripts/validate-component-catalog.py` validates the schema and detects drift in
service ownership, Compose files, profiles, networks, mount access modes, named volumes,
secret-variable references, and health checks. `bash tests/test_repo.sh` also resolves
the base, worker, OpenClaw, and combined Compose models in CI.

## Current Inventory

| Component | Services | Current profile | Required dependencies |
|-----------|----------|-----------------|-----------------------|
| `traefik` | `traefik` | none (mandatory) | none |
| `demo-db` | `demo-db` | `demo-db` | none |
| `n8n` | `n8n` | `n8n` | none |
| `openclaw` | `openclaw` | `openclaw` | none |
| `ollama` | `ollama` | `local-model` | none |
| `qdrant` | `qdrant` | `qdrant` | none |
| `langfuse` | `langfuse`, `langfuse-db` | `langfuse` | none |
| `litellm` | `litellm`, `litellm-db` | `litellm` | none |
| `dify` | nine Dify services | `dify` | `qdrant` |
| `ffmpeg-worker` | `ffmpeg-worker` | `ffmpeg-worker` | `n8n` |

Initial presets resolve as follows:

| Preset | Components | Profiles |
|--------|------------|----------|
| `n8n-cloud` | Traefik, n8n, LiteLLM | `n8n,litellm` |
| `dify-cloud` | Traefik, Dify, Qdrant, LiteLLM | `dify,qdrant,litellm` |
| `openclaw` | Traefik, OpenClaw | `openclaw` |

Resource values and their measurement limits are documented in
[Resource Baselines](resource-baselines.md). The validator requires every component to
record observed metrics or declare that it remains unmeasured.

## Maintenance

Update the catalog in the same change whenever a Compose service changes its ownership,
profile, network, mount, or health check. Classify new storage before merge. Use
`backup: unresolved` only to expose an existing ambiguity; resolve it before implementing
selection-aware backup and restore.

Run:

```bash
python3 scripts/validate-component-catalog.py
python3 scripts/validate-compose-presets.py
bash tests/test_repo.sh
```

The catalog validator requires Python 3 and PyYAML. Preset resolution also requires
Docker Compose. CI installs `yamllint`, whose Ubuntu package supplies PyYAML, and requires
Docker Compose before repository tests run.
