# Project TODO

## Modular stack constructor

Decision: [ADR-0008](adr/0008-modular-stack-constructor.md). Delivery sequence:
[Roadmap](ROADMAP.md).

### Discovery and contracts

- [x] Inventory every Compose service, volume, network, route, secret, health check,
  backup target, and host prerequisite.
- [x] Define the component catalog schema and validate it in CI.
- [x] Record required/optional dependencies and conflicts for each component.
- [x] Define supported LiteLLM client/provider contracts; do not equate generic
  OpenAI-compatible APIs with full feature compatibility. The contract remains
  `declared-not-executed` until Phase 1 acceptance tests pass.
- [x] Measure baseline and representative stack resource usage on supported VPS sizes;
  treat idle observations as sizing evidence, not deployment minimums or load tests.

### Compose profiles

- [ ] Keep Traefik outside all optional profiles.
- [ ] Group n8n, Dify, OpenClaw, LiteLLM, Ollama, Qdrant, Langfuse, demo database, and
  workers into stable product-level profiles.
- [ ] Ensure all internal Dify services share one user-facing Dify selection.
- [ ] Add LiteLLM Proxy and a dedicated persistent database with pinned versions,
  health checks, internal networking, backup, and secret handling.
- [ ] Ensure `docker compose config` succeeds for every supported preset and dependency
  closure without starting unrelated services.

### Selector and saved state

- [ ] Implement an interactive deployment menu with presets and a custom checklist.
- [ ] Implement non-interactive `--preset`, `--components`, `--plan`, and confirmation
  behavior suitable for SSH and cloud-init.
- [ ] Resolve dependencies and reject conflicts before generating Compose profiles.
- [ ] Save the resolved selection in a gitignored machine-readable file.
- [ ] Show a plan containing selected/automatic components, resource estimates, routes,
  volumes, and create/recreate/stop actions.
- [ ] Preserve existing secrets and generate values only for newly selected components.
- [ ] Preserve volumes when a component is deselected; require a separate confirmation
  to delete data.

### Resource and compatibility gates

- [ ] Check CPU, available RAM, swap, disk, port conflicts, Docker/Compose versions, and
  component-specific host prerequisites before deployment.
- [ ] Refuse combinations below hard minimums and require confirmation for recommended
  capacity warnings.
- [ ] Treat Ollama as explicit opt-in and estimate model memory/disk before pulling.
- [ ] Validate model endpoints, credentials, and provider capabilities for selected
  integrations without printing secrets.
- [ ] Verify that Traefik only exposes routes for selected public components.

### Operations and migration

- [ ] Make validation, backup, diagnostics, updates, and restore selection-aware.
- [ ] Add a migration preview for existing all-in-one installations.
- [ ] Detect and report orphaned containers without deleting them automatically.
- [ ] Add rollback instructions for selection changes and failed upgrades.
- [ ] Document how to add a new catalog component and compatibility rule.

### Tests and acceptance

- [ ] Test `n8n-cloud`, `dify-cloud`, `openclaw`, and representative custom presets in CI.
- [ ] Test dependency closure, conflicts, idempotent reruns, and non-interactive operation.
- [ ] Test that deselection preserves volumes and unrelated secrets.
- [ ] Smoke-test each preset on a clean host and an upgraded existing host.
- [ ] Confirm that `n8n-cloud` starts no Dify/OpenClaw/Langfuse/Ollama services.
- [ ] Confirm that `dify-cloud` includes all Dify and LiteLLM dependencies.
