# Project Roadmap

This roadmap implements [ADR-0008](../adr/0008-modular-stack-constructor.md). It tracks
phase outcomes and exit gates, not calendar commitments. Detailed work uses matching
phase and task IDs in [Project TODO](TODO.md).

## Current status

**Current phase:** P1 — Compose profile foundation

| Phase | Status | TODO progress | Next gate |
|-------|--------|--------------:|-----------|
| [P0](#p0-baseline-and-component-catalog) | Complete | 5/5 | Complete |
| [P1](#p1-compose-profile-foundation) | In progress | 9/11 | Clean-host preset and LiteLLM acceptance |
| [P2](#p2-deployment-selector) | Planned | 0/14 | Start after P1 exit gate |
| [P3](#p3-selection-aware-operations) | Planned | 1/7 | Complete lifecycle coverage |
| [P4](#p4-existing-host-migration) | In progress | 5/6 | Idempotency and rollback test |

Status meanings:

- **Complete:** exit criteria passed with repository or runtime evidence.
- **In progress:** implementation or acceptance work is active.
- **Planned:** work has not started, except explicitly recorded prerequisites.
- **Blocked:** progress requires a named decision, dependency, or external action.

## P0: Baseline and component catalog

**Status:** Complete

**Outcome:** one reviewed source of truth for selectable products and dependencies.

**Detailed tasks:** [P0 tasks](TODO.md#p0-baseline-and-component-catalog)

- [x] Inventory the current Compose and host-specific requirements.
- [x] Define and validate the component catalog schema.
- [x] Establish resource measurement and compatibility contracts.
- [x] Add CI drift checks for catalog, Compose, contracts, and documentation.
- [x] Record Phase 0 evidence in versioned reference documentation.
- [x] **Exit gate:** catalog and contracts cover every managed service and pass CI.

Evidence: `config/components.yml`, `config/litellm-contracts.yml`,
`docs/reference/resource-baselines.md`, and merged PR #23.

## P1: Compose profile foundation

**Status:** In progress

**Outcome:** optional products resolve independently while Traefik remains mandatory.

**Detailed tasks:** [P1 tasks](TODO.md#p1-compose-profile-foundation)

- [x] Add product-level profiles and dependency groups.
- [x] Add LiteLLM Proxy and its dedicated database.
- [x] Define `n8n-cloud`, `dify-cloud`, and `openclaw` presets.
- [x] Validate resolved Compose service closures in CI.
- [x] Isolate LiteLLM networks and keep its per-user Admin UI on host loopback for SSH-tunnel access.
- [x] Support selectable HTTP-01 and Cloudflare DNS-01 certificate modes.
- [x] Add a standalone Yopass profile with persistent encrypted-secret storage and HTTPS routing.
- [ ] Smoke-test each preset on a clean host without unrelated services.
- [ ] Execute LiteLLM provider, client, key-isolation, persistence, and redaction tests.
- [ ] **Exit gate:** each preset starts only its declared dependency closure and passes
  its Phase 1 acceptance checks.

Static implementation and CI evidence landed in merged PR #24. Production deployment to
the existing all-in-one host remains blocked until P4 provides migration reconciliation.

## P2: Deployment selector

**Status:** Planned

**Outcome:** operators configure a host through presets or a component checklist.

**Detailed tasks:** [P2 tasks](TODO.md#p2-deployment-selector)

- [ ] Implement interactive and non-interactive selection interfaces.
- [ ] Resolve dependencies, conflicts, and host prerequisites before deployment.
- [ ] Add plan output, saved selection state, and resource estimates.
- [ ] Reconcile create/recreate/stop actions without deleting data.
- [ ] Add selector, idempotency, conflict, and data-preservation tests.
- [ ] **Exit gate:** a clean VPS deploys each preset unattended and repeated deployment
  of the same selection is idempotent.

## P3: Selection-aware operations

**Status:** Planned

**Outcome:** lifecycle commands act only on the selected stack.

**Detailed tasks:** [P3 tasks](TODO.md#p3-selection-aware-operations)

- [x] Make live validation profile-aware.
- [ ] Make diagnostics, backup, restore, and upgrades selection-aware.
- [ ] Add orphan detection, rollback guidance, and component removal workflow.
- [ ] Add selected model/provider checks for LiteLLM and Ollama.
- [ ] Verify backup and restore paths for every preset.
- [ ] **Exit gate:** each preset has focused health checks and a verified recovery path.

The completed validation prerequisite landed during P1 because profile-specific stacks
would otherwise report false failures. P3 remains planned until lifecycle coverage starts.

## P4: Existing-host migration

**Status:** In progress

**Outcome:** current all-in-one installations adopt the constructor without data loss.

**Detailed tasks:** [P4 tasks](TODO.md#p4-existing-host-migration)

- [x] Detect running components, volumes, credentials, and host overrides.
- [x] Migrate the live OpenClaw Gateway and preserved state to the sandbox's rootless
  daemon; verify an agent turn and sandbox tool on OpenClaw 2026.9.9.
- [x] Generate a migration plan matching current intent.
- [x] Preserve volumes and secrets while stopping deselected products.
- [ ] Test upgrade and rollback against an existing-host fixture.
- [x] Roll out to the lab host and verify resources and service behavior.
- [ ] **Exit gate:** the lab uses saved selection state, has no unmanaged project
  containers, and has recorded rollback evidence.

Runtime evidence for release `212bb0a`: checksum-verified cold backup; 13 project volumes
preserved; 5 selected services healthy; 14 deselected containers stopped; validation
passed 19/19; available memory increased from 2.7 GiB to 4.7 GiB and swap use decreased
from 1.9 GiB to 778 MiB. The backup recovery path is recorded but an intentional rollback
and idempotent rerun remain untested.

## Deferred until explicitly selected

- Automatic deletion of deselected component data.
- Kubernetes or multi-host orchestration.
- Automatic cloud sizing or VPS purchasing.
- Treating arbitrary provider APIs as LiteLLM-compatible without contract tests.
