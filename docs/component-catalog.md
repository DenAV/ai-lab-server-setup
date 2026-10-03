# Component Catalog

`config/components.yml` is the machine-readable inventory for the modular stack
constructor defined by [ADR-0008](adr/0008-modular-stack-constructor.md). During Phase 0
it records the current Compose behavior; Phase 1 will change profiles and add LiteLLM in
the catalog and Compose together.

## Schema

The root contains:

| Field | Contract |
|-------|----------|
| `schema_version` | Catalog format version; currently `1` |
| `compose_files` | Repository Compose files included in drift validation |
| `host_prerequisites` | Stable prerequisite IDs and operator-facing descriptions |
| `resource_baseline` | Versioned measurement context, stack totals, and supported host classes |
| `components` | User-selectable product IDs mapped to their current contracts |

Every component records:

| Field | Contract |
|-------|----------|
| `required` | Whether the component is always selected; only Traefik is mandatory |
| `services` | Compose services owned by the component |
| `compose_files` | Files that declare or extend those services |
| `profile` | Current shared Compose profile, or `null` when no profile exists yet |
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
| `demo-db` | `demo-db` | none | none |
| `n8n` | `n8n` | none | none |
| `openclaw` | `openclaw` | none | none |
| `ollama` | `ollama` | `local-model` | none |
| `qdrant` | `qdrant` | none | none |
| `langfuse` | `langfuse`, `langfuse-db` | none | none |
| `dify` | nine Dify services | none | `qdrant` |
| `ffmpeg-worker` | `ffmpeg-worker` | none | `n8n` |

LiteLLM is intentionally absent because no managed service exists yet. Add it only with
its pinned images, database, secrets, health checks, storage, and Compose contract in
Phase 1.

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
bash tests/test_repo.sh
```

The validator requires Python 3 and PyYAML. CI installs `yamllint`, whose Ubuntu package
supplies PyYAML, and separately requires Docker Compose before repository tests run.
