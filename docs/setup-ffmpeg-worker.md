# FFmpeg Worker

## Overview

`ffmpeg-worker` is an internal HTTP service for media processing from n8n.
It keeps the n8n image clean and exposes only a small allowlisted API instead
of arbitrary shell command execution.

- **Internal URL:** `http://ffmpeg-worker:8080`
- **Network:** `ai-net`
- **External port:** none
- **Shared data path:** `/data/cca`
- **Host data path:** `/home/lab/client-conversation-analyzer-data`

## Start

Start the platform with the worker compose file:

```bash
docker compose -f docker-compose.yml -f docker-compose.workers.yml up -d --build
```

Start or rebuild only the worker:

```bash
docker compose -f docker-compose.yml -f docker-compose.workers.yml up -d --build ffmpeg-worker
```

Check status:

```bash
docker compose -f docker-compose.yml -f docker-compose.workers.yml ps ffmpeg-worker
docker compose -f docker-compose.yml -f docker-compose.workers.yml logs -f ffmpeg-worker
```

## API

### Health

From another container on `ai-net`:

```bash
curl -fsS http://ffmpeg-worker:8080/health
```

Expected response:

```json
{"status":"ok"}
```

### Convert

Request:

```http
POST /convert
Content-Type: application/json
```

```json
{
  "input": "incoming/source.wav",
  "output": "processed/source.mp3",
  "preset": "mp3-128k"
}
```

Response:

```json
{
  "status": "ok",
  "output": "processed/source.mp3"
}
```

Paths are relative to `/data/cca`. The worker rejects paths that escape this
directory.

## Presets

Supported presets:

| Preset | Purpose |
|--------|---------|
| `mp3-128k` | Convert audio to MP3 at 128 kbps |
| `wav-16k-mono` | Convert audio to 16 kHz mono WAV |
| `extract-audio` | Extract audio stream without re-encoding |

Add new presets in `config/ffmpeg-worker/app.py`. Prefer presets over raw
ffmpeg arguments so n8n cannot execute arbitrary shell commands.

## n8n Integration

The worker compose file also mounts the shared data directory into n8n:

```text
/home/lab/client-conversation-analyzer-data:/data/cca
```

Example n8n flow:

1. Save the input file under `/data/cca/incoming/`.
2. Add an HTTP Request node.
3. Set method to `POST`.
4. Set URL to `http://ffmpeg-worker:8080/convert`.
5. Send JSON body with `input`, `output`, and `preset`.
6. Read the output file from `/data/cca/processed/`.

Example HTTP Request body:

```json
{
  "input": "incoming/{{$json.fileName}}",
  "output": "processed/{{$json.fileName}}.mp3",
  "preset": "mp3-128k"
}
```

## Troubleshooting

| Issue | Check |
|-------|-------|
| n8n cannot reach worker | Confirm both services use `ai-net` and call `http://ffmpeg-worker:8080` |
| Input file not found | Confirm the file exists under `/data/cca` in both containers |
| Permission denied | Check ownership of `/home/lab/client-conversation-analyzer-data` on the host |
| Unsupported preset | Call `/presets` or review `config/ffmpeg-worker/app.py` |
| Long conversion fails | Check worker logs and resource limits in `docker-compose.workers.yml` |
