# ADR-0007: Retire Flowise from the AI Lab

- **Status:** accepted
- **Date:** 2026-09-28

## Context

The Flowise maintainers [froze development on July 29, archived the upstream
repository on August 13, and ended official support on August 31,
2026](https://github.com/FlowiseAI/Flowise/discussions/6727). The previously
published code remains available under the Apache 2.0 license; the archive
does not revoke its open-source license.

The lab owner no longer uses Flowise. No services in this Compose project depend
on it, and no saved n8n workflow referenced it when the removal was planned.

## Decision

Remove Flowise from the supported Compose stack and active setup/integration
instructions. Remove its container, data volume, image, and archived data from
the lab host after the configuration is deployed. Remove its generated credentials
from the host's `.env` and `.secrets`. The owner removes the Cloudflare DNS record
separately, after confirming that `flow` is an explicit record rather than a wildcard.

## Historical documentation

The last pre-retirement setup guide is available at commit
`e4e362dd656221e5d7b33b1cff7ba0d427be82b7` in this repository:

```bash
git show e4e362dd656221e5d7b33b1cff7ba0d427be82b7:docs/setup-flowise.md
```

The earlier ADRs retain their original context as historical records.

## Consequences

- The lab no longer exposes a `flow.<domain>` route or stores Flowise data.
- Deleting the volume and the backup archive permanently removes this lab's
  Flowise SQLite data and keys. Old Git commits preserve only documentation,
  not runtime data or secrets.
- Dify, n8n, OpenClaw, Qdrant, Langfuse, Traefik, and the optional workers
  remain in the stack.
