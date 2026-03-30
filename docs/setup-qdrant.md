# Qdrant — Vector Database

## Overview

Qdrant stores and searches vector embeddings for RAG (Retrieval-Augmented
Generation) pipelines. Runs as a standalone Docker container.

- **Port:** 6333 (HTTP API, localhost only)
- **gRPC:** 6334 (not exposed by default)
- **Data:** Docker volume `qdrant_data`
- **Dashboard:** `http://localhost:6333/dashboard`

## Installation

Qdrant is started automatically by `setup.sh`. Manual start:

```bash
docker run -d --name qdrant --restart unless-stopped \
  -p 6333:6333 \
  -v qdrant_data:/qdrant/storage \
  qdrant/qdrant:v1.12.1
```

## Management

```bash
# Start / stop
docker start qdrant
docker stop qdrant

# View logs
docker logs -f qdrant

# Check status
curl http://localhost:6333/healthz

# Shell into container
docker exec -it qdrant bash
```

### Aliases

```bash
qdrant-start   # Start or create container
qdrant-stop    # Stop container
```

## API Usage

### List collections

```bash
curl http://localhost:6333/collections
```

### Create a collection

```bash
curl -X PUT http://localhost:6333/collections/my_docs -H 'Content-Type: application/json' -d '{
  "vectors": {
    "size": 768,
    "distance": "Cosine"
  }
}'
```

> Use `size: 768` for `nomic-embed-text`, `size: 1536` for OpenAI `text-embedding-3-small`.

### Insert vectors

```bash
curl -X PUT http://localhost:6333/collections/my_docs/points -H 'Content-Type: application/json' -d '{
  "points": [
    {
      "id": 1,
      "vector": [0.1, 0.2, ...],
      "payload": {"text": "Docker is a container platform", "source": "docs"}
    }
  ]
}'
```

### Search

```bash
curl -X POST http://localhost:6333/collections/my_docs/points/search -H 'Content-Type: application/json' -d '{
  "vector": [0.1, 0.2, ...],
  "limit": 5
}'
```

### Delete a collection

```bash
curl -X DELETE http://localhost:6333/collections/my_docs
```

## Python Integration

```bash
pip install qdrant-client
```

```python
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct

client = QdrantClient(host="localhost", port=6333)

# Create collection
client.create_collection(
    collection_name="my_docs",
    vectors_config=VectorParams(size=768, distance=Distance.COSINE),
)

# Insert points
client.upsert(
    collection_name="my_docs",
    points=[
        PointStruct(
            id=1,
            vector=[0.1, 0.2, ...],  # 768-dim vector
            payload={"text": "Docker is a container platform"},
        ),
    ],
)

# Search
results = client.search(
    collection_name="my_docs",
    query_vector=[0.1, 0.2, ...],
    limit=5,
)
for result in results:
    print(result.payload["text"], result.score)
```

## RAG Pipeline Example (Ollama + Qdrant)

```python
from openai import OpenAI
from qdrant_client import QdrantClient

ollama = OpenAI(base_url="http://localhost:11434/v1", api_key="unused")
qdrant = QdrantClient(host="localhost", port=6333)

def get_embedding(text: str) -> list[float]:
    response = ollama.embeddings.create(
        model="nomic-embed-text",
        input=text,
    )
    return response.data[0].embedding

def search_docs(query: str, limit: int = 3) -> list[str]:
    vector = get_embedding(query)
    results = qdrant.search(
        collection_name="my_docs",
        query_vector=vector,
        limit=limit,
    )
    return [r.payload["text"] for r in results]

# Search and generate
query = "How does Docker networking work?"
context = search_docs(query)
response = ollama.chat.completions.create(
    model="llama3.2",
    messages=[
        {"role": "system", "content": f"Answer based on context:\n{''.join(context)}"},
        {"role": "user", "content": query},
    ],
)
print(response.choices[0].message.content)
```

## Data Management

### Backup

```bash
# Stop container, backup volume
docker stop qdrant
docker run --rm -v qdrant_data:/data -v $(pwd):/backup \
  ubuntu tar czf /backup/qdrant-backup-$(date +%Y%m%d).tar.gz /data
docker start qdrant
```

### Restore

```bash
docker stop qdrant
docker run --rm -v qdrant_data:/data -v $(pwd):/backup \
  ubuntu bash -c "rm -rf /data/* && tar xzf /backup/qdrant-backup-YYYYMMDD.tar.gz -C /"
docker start qdrant
```

### Reset (delete all data)

```bash
docker stop qdrant
docker rm qdrant
docker volume rm qdrant_data
# Recreate:
qdrant-start
```

## Configuration

For production use, add API key authentication:

```bash
docker run -d --name qdrant --restart unless-stopped \
  -p 6333:6333 \
  -v qdrant_data:/qdrant/storage \
  -e QDRANT__SERVICE__API_KEY=your-secret-key \
  qdrant/qdrant:v1.12.1
```

Then pass the key in requests:

```bash
curl -H "api-key: your-secret-key" http://localhost:6333/collections
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Container not starting | Check logs: `docker logs qdrant` |
| Port already in use | `docker ps` — check for conflicts |
| Out of disk space | `docker system df`, clean up old images |
| Slow searches | Create payload index: `PUT /collections/{name}/index` |
| Collection not found | Verify name: `curl localhost:6333/collections` |
