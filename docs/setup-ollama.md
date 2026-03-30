# Ollama — Local LLM Inference

## Overview

Ollama runs local LLM models on CPU (or GPU if available). Installed natively
on the host (not in Docker) for direct hardware access and simpler model
management.

- **Port:** 11434 (localhost only, not exposed to internet)
- **API:** `http://localhost:11434/v1` (OpenAI-compatible)
- **Models dir:** `~/.ollama/models`
- **Service:** systemd (`ollama.service`)

## Installation

Ollama is installed automatically by `setup.sh`. Manual install:

```bash
curl -fsSL https://ollama.com/install.sh | sh
sudo systemctl enable ollama
sudo systemctl start ollama
```

## Model Management

```bash
# List installed models
ollama list

# Pull a model
ollama pull llama3.2
ollama pull nomic-embed-text
ollama pull mistral
ollama pull codellama

# Remove a model
ollama rm <model-name>

# Show model info
ollama show llama3.2

# Run interactive chat
ollama run llama3.2
```

### Recommended Models

| Model | Size | Purpose |
|-------|------|---------|
| `llama3.2` | ~2 GB | General chat, reasoning |
| `nomic-embed-text` | ~270 MB | Text embeddings for RAG |
| `mistral` | ~4 GB | General purpose, code |
| `codellama` | ~4 GB | Code generation |
| `phi3` | ~2 GB | Lightweight, fast |

> On CPX22 (4 GB RAM), stick to models under 4 GB. Larger models
> need CCX23+ (16 GB RAM).

## API Usage

### Check status

```bash
curl http://localhost:11434/api/tags
```

### Generate completion

```bash
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2",
  "prompt": "What is Docker?",
  "stream": false
}'
```

### OpenAI-compatible endpoint

```bash
curl http://localhost:11434/v1/chat/completions -d '{
  "model": "llama3.2",
  "messages": [{"role": "user", "content": "Hello"}]
}'
```

### Embeddings

```bash
curl http://localhost:11434/api/embeddings -d '{
  "model": "nomic-embed-text",
  "prompt": "The quick brown fox"
}'
```

## Python Integration

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:11434/v1",
    api_key="unused",  # Ollama doesn't need a key
)

response = client.chat.completions.create(
    model="llama3.2",
    messages=[{"role": "user", "content": "Hello"}],
)
print(response.choices[0].message.content)
```

## Service Management

```bash
# Status
sudo systemctl status ollama

# Start / stop / restart
sudo systemctl start ollama
sudo systemctl stop ollama
sudo systemctl restart ollama

# View logs
journalctl -u ollama -f

# Check model download progress
tail -f /tmp/ollama-pull.log
```

## Configuration

Ollama environment variables (set in `/etc/systemd/system/ollama.service`):

| Variable | Default | Description |
|----------|---------|-------------|
| `OLLAMA_HOST` | `127.0.0.1:11434` | Listen address |
| `OLLAMA_MODELS` | `~/.ollama/models` | Models directory |
| `OLLAMA_NUM_PARALLEL` | `1` | Concurrent requests |
| `OLLAMA_MAX_LOADED_MODELS` | `1` | Models in memory |

To change settings:

```bash
sudo systemctl edit ollama
```

Add:

```ini
[Service]
Environment="OLLAMA_NUM_PARALLEL=2"
Environment="OLLAMA_MAX_LOADED_MODELS=2"
```

Then reload:

```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `ollama: command not found` | Re-run install: `curl -fsSL https://ollama.com/install.sh \| sh` |
| Service not starting | Check logs: `journalctl -u ollama -n 50` |
| Out of memory | Use smaller models or increase RAM |
| Slow inference | Normal on CPU — consider CCX23+ for better performance |
| Models not downloading | Check disk space: `df -h` |
