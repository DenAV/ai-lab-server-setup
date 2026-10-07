# Project TODO

This task list implements the phases in [Project Roadmap](ROADMAP.md) and
[ADR-0008](../adr/0008-modular-stack-constructor.md). Phase IDs, statuses, and completion
counts must match the roadmap in the same change.

**Current phase:** [P1 — Compose profile foundation](ROADMAP.md#p1-compose-profile-foundation)

## P0: Baseline and component catalog

**Status:** Complete — 5/5 tasks

- [x] **P0-01** Inventory every Compose service, volume, network, route, secret, health
  check, backup target, and host prerequisite.
- [x] **P0-02** Define the component catalog schema and validate it in CI.
- [x] **P0-03** Record required/optional dependencies and conflicts for each component.
- [x] **P0-04** Define supported LiteLLM client/provider contracts without treating
  generic OpenAI-compatible APIs as fully compatible.
- [x] **P0-05** Measure representative resource usage and record evidence-qualified VPS
  sizing guidance.

## P1: Compose profile foundation

**Status:** In progress — 9/11 tasks

- [x] **P1-01** Keep Traefik outside all optional profiles.
- [x] **P1-02** Group n8n, Dify, OpenClaw, LiteLLM, Ollama, Qdrant, Langfuse, demo
  database, and workers into stable product-level profiles.
- [x] **P1-03** Ensure all internal Dify services share one user-facing Dify selection.
- [x] **P1-04** Add LiteLLM Proxy and a dedicated persistent database with pinned
  versions, health checks, internal networking, backup, and secret handling.
- [x] **P1-05** Define `n8n-cloud`, `dify-cloud`, and `openclaw` preset dependency closures.
- [x] **P1-06** Verify in CI that `docker compose config` succeeds for every preset and
  overlay without resolving unrelated services.
- [x] **P1-09** Isolate LiteLLM database, client, and upstream networks; restrict public
  access by disabling Traefik discovery and binding the Admin UI to host loopback for
  SSH-tunnel administration; disable shared env-login after verifying a per-user admin.
- [x] **P1-10** Support default HTTP-01 and optional Cloudflare DNS-01 certificate modes
  without opening upstream TCP 80 for DNS-01 deployments.
- [x] **P1-11** Add a standalone Yopass profile with an isolated persistent Redis
  dependency, HTTPS routing, and live health validation.
- [ ] **P1-07** Smoke-test each preset on a clean host and confirm the running service
  closure, persistence, and restart behavior.
- [ ] **P1-08** Execute the LiteLLM provider, n8n, Dify, virtual-key isolation,
  persistence, and logging-redaction acceptance tests; then update the contract status.

## P2: Deployment selector

**Status:** Planned — 0/14 tasks

- [ ] **P2-01** Implement an interactive deployment menu with presets and a custom
  checklist.
- [ ] **P2-02** Implement non-interactive `--preset`, `--components`, `--plan`, and
  confirmation behavior suitable for SSH and cloud-init.
- [ ] **P2-03** Resolve dependencies and reject conflicts before generating profiles.
- [ ] **P2-04** Save the resolved selection in a gitignored machine-readable file.
- [ ] **P2-05** Show selected and automatic components, resource estimates, routes,
  volumes, and create/recreate/stop actions in the plan.
- [ ] **P2-06** Preserve existing secrets and generate values only for newly selected
  components.
- [ ] **P2-07** Preserve volumes when deselecting a component and require separate
  confirmation before data deletion.
- [ ] **P2-08** Check CPU, RAM, swap, disk, ports, Docker/Compose versions, and host
  prerequisites before deployment.
- [ ] **P2-09** Refuse combinations below hard minimums and confirm recommended-capacity
  warnings.
- [ ] **P2-10** Keep Ollama explicit opt-in and estimate model memory/disk before pulls.
- [ ] **P2-11** Verify Traefik exposes routes only for selected public components.
- [ ] **P2-12** Test representative custom selections in CI.
- [ ] **P2-13** Test conflicts, dependency closure, idempotency, and non-interactive use.
- [ ] **P2-14** Test that deselection preserves volumes and unrelated secrets.

## P3: Selection-aware operations

**Status:** Planned — 1/7 tasks

- [x] **P3-01** Make live validation profile-aware, including LiteLLM and Qdrant-only
  selections.
- [ ] **P3-02** Make backup, diagnostics, updates, and restore selection-aware.
- [ ] **P3-03** Detect and report orphaned containers without automatic deletion.
- [ ] **P3-04** Add rollback instructions for selection changes and failed upgrades.
- [ ] **P3-05** Document how to add a catalog component and compatibility rule.
- [ ] **P3-06** Validate selected model endpoints, credentials, and provider capabilities
  without printing secrets.
- [ ] **P3-07** Verify backup and restore paths for every supported preset.

## P4: Existing-host migration

**Status:** In progress — 4/5 tasks

- [x] **P4-01** Detect running components, volumes, credentials, and host overrides.
- [x] **P4-02** Generate a migration preview matching the current installation intent.
- [x] **P4-03** Preserve volumes and secrets while explicitly stopping deselected products.
- [ ] **P4-04** Test clean-host and upgraded-host migration, rollback, and idempotency.
- [x] **P4-05** Apply the constructor to the lab host and verify selected services,
  resource reduction, and the recovery artifact.
