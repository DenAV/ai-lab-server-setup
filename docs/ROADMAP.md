# Project Roadmap

This roadmap implements [ADR-0008](adr/0008-modular-stack-constructor.md). It describes
delivery order, not calendar commitments. Detailed checkboxes are in [TODO](TODO.md).

## Phase 0: Baseline and component catalog

**Outcome:** one reviewed source of truth for selectable products and dependencies.

- Inventory the current Compose and host-specific requirements.
- Define and validate the component catalog schema.
- Establish resource measurement and compatibility contracts.
- Preserve the current full-stack behavior until equivalent selections are tested.

**Exit criteria:** the catalog represents every managed service and CI detects drift
between the catalog, Compose profiles, validation, backup, and documentation.

## Phase 1: Compose profile foundation

**Outcome:** optional products can be resolved independently while Traefik remains always
enabled.

- Add product-level profiles and dependency groups.
- Add LiteLLM Proxy and its database as a supported optional component.
- Define the initial `n8n-cloud`, `dify-cloud`, and `openclaw` presets.
- Add resolved Compose tests for each preset.

**Exit criteria:** every preset resolves and starts only its declared dependency closure;
no data migration or interactive selector is required yet.

## Phase 2: Deployment selector

**Outcome:** operators can configure a host through presets or a checklist.

- Implement interactive and non-interactive interfaces.
- Add plan/preview output and saved selection state.
- Add resource, compatibility, host prerequisite, and secret checks.
- Reconcile create/recreate/stop actions without deleting data.

**Exit criteria:** a clean VPS can deploy each preset unattended, and rerunning the same
selection is idempotent.

## Phase 3: Selection-aware operations

**Outcome:** lifecycle commands act only on the selected stack.

- Update validation, diagnostics, backup, restore, upgrade, and support bundles.
- Add orphan detection, rollback guidance, and component removal workflow.
- Add model/provider checks for LiteLLM and optional Ollama integrations.

**Exit criteria:** each preset has a verified backup/restore path and focused health checks.

## Phase 4: Existing-host migration

**Outcome:** current all-in-one installations can adopt the constructor without data loss.

- Detect running components, volumes, credentials, and host overrides.
- Generate a migration plan matching current intent.
- Preserve volumes and secrets while stopping deselected products.
- Roll out to the lab host and verify resource reduction and service behavior.

**Exit criteria:** the existing lab is represented by saved selection state, no unmanaged
project containers remain, and rollback evidence is recorded.

## Deferred until explicitly selected

- Automatic deletion of deselected component data.
- Kubernetes or multi-host orchestration.
- Automatic cloud sizing or VPS purchasing.
- Treating arbitrary provider APIs as LiteLLM-compatible without contract tests.
