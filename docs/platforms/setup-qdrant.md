# Qdrant — Vector Database

## Overview

Qdrant stores vector embeddings for RAG pipelines. This repository runs it only through
the `qdrant` Compose profile:

- **Container:** `qdrant-compose`
- **Network:** internal `ai-net`; no host port is published
- **Data:** named volume `qdrant-data`
- **Authentication:** `QDRANT_API_KEY` from `.env`
- **Image:** `qdrant/qdrant:v1.19.1`

Do not create a standalone `qdrant` container or publish port 6333. `setup.sh` disables
legacy standalone containers because they bypass authentication, profiles, and the
managed volume.

## Start And Stop

Enable Qdrant directly:

```bash
COMPOSE_PROFILES=qdrant docker compose config --services
COMPOSE_PROFILES=qdrant docker compose up -d qdrant
```

The `dify-cloud` preset includes Qdrant automatically:

```bash
COMPOSE_PROFILES=dify,qdrant,litellm docker compose up -d
```

Management commands:

```bash
docker compose --profile qdrant ps qdrant
docker compose --profile qdrant logs -f qdrant
docker compose --profile qdrant stop qdrant
```

The installed `qdrant-start` and `qdrant-stop` aliases run these Compose-managed
operations; they never create a second container.

## Connectivity

Other services on `ai-net` use:

```text
http://qdrant-compose:6333
```

Pass `QDRANT_API_KEY` through the client credential store or the `api-key` HTTP header.
Do not copy the key into workflow code, documentation, or logs.

For an operator-only host check, resolve the internal container address without
publishing a port:

```bash
QDRANT_IP="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' qdrant-compose)"
QDRANT_API_KEY="$(sed -n 's/^QDRANT_API_KEY=//p' .env)"
printf 'header = "api-key: %s"\n' "${QDRANT_API_KEY}" | \
  curl -fsS --config - "http://${QDRANT_IP}:6333/collections"
unset QDRANT_API_KEY
```

## Client Example

From an application container attached to `ai-net`:

```python
import os

from qdrant_client import QdrantClient

client = QdrantClient(
    url="http://qdrant-compose:6333",
    api_key=os.environ["QDRANT_API_KEY"],
)
collections = client.get_collections()
```

Use the same embedding model and dimensions for indexing and querying. For example,
OpenAI `text-embedding-3-small` defaults to 1536 dimensions unless configured otherwise.

## Backup And Restore

The component catalog classifies `qdrant-data` as a required backup target. Stop Qdrant
before a filesystem-level volume backup:

```bash
docker compose --profile qdrant stop qdrant
docker run --rm \
  -v ai-lab-server-setup_qdrant-data:/data:ro \
  -v "$(pwd):/backup" \
  alpine:3.22 \
  tar czf /backup/qdrant-data-backup.tar.gz -C /data .
docker compose --profile qdrant start qdrant
```

Test restore procedures on a separate volume before relying on a backup. Never use
`docker compose down -v` as part of an update or profile change.

## Troubleshooting

| Issue | Check |
|-------|-------|
| Container absent | Confirm `qdrant` is present in `COMPOSE_PROFILES` |
| Authentication error | Verify the client uses the current `QDRANT_API_KEY` |
| Connection refused | Confirm both services share `ai-net` and use `qdrant-compose:6333` |
| Existing `qdrant` container | Stop and rename it before using the Compose-managed service |
| Out of disk space | Check `docker system df` and volume growth; do not prune volumes |
