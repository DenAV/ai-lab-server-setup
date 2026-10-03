# Resource Baselines

The component catalog contains the Phase 0 resource baseline used by the modular stack
constructor. These values support selection previews and capacity warnings. They are not
hard limits or load-test results.

## Measurement

The baseline was captured on 2026-10-03 from the deployed cloud-model stack at repository
revision `3956f298f138b219ba343b1e07c27acef67d3753`:

- 4 vCPU, 7,746 MiB usable RAM, 4,096 MiB swap, and a 149.9 GiB root disk;
- Docker 29.8.0 and Docker Compose 5.5.1;
- 17 managed containers running for at least four days;
- six `docker stats --no-stream` samples at ten-second intervals;
- no synthetic workload; periodic health checks account for the observed CPU peaks.

Only containers owned by `config/components.yml` were included. Other workloads on the
host were excluded. Persistent data is deduplicated across shared mounts. Logical image
size sums each distinct managed image once and does not account for registry compression
or layers shared with unrelated images.

## Observed Idle Usage

| Component | Memory maximum | CPU peak |
|-----------|---------------:|---------:|
| Traefik | 57.6 MiB | 0.27% |
| n8n | 411.7 MiB | 4.54% |
| Dify group | 2,562.0 MiB | 13.51% |
| OpenClaw | 762.2 MiB | 1.38% |
| Qdrant | 31.7 MiB | 0.19% |
| Langfuse group | 181.8 MiB | 3.37% |
| Demo database | 10.4 MiB | 3.54% |
| FFmpeg worker | 13.4 MiB | 4.88% |
| Ollama | not measured | not measured |

The managed stack reached 4,031 MiB container memory and 22.2% aggregate CPU at the
highest sampled interval. Its distinct images occupied 15,579 MiB logically, while
named volumes and the worker bind mount held 1,999 MiB. The host had 2,732 MiB available
RAM and was using 1,892 MiB swap during the observation window. This makes 8 GiB the
minimum recommended class for the complete measured cloud stack, not a guarantee of
headroom under concurrent workflows or upgrades.

## Host Classes

| Class | vCPU | RAM | Disk | Evidence | Fit |
|-------|-----:|----:|-----:|----------|-----|
| Minimum | 2 | 4 GiB | 40 GiB | Projected | Base components only; not the measured full stack |
| Recommended | 4 | 8 GiB | 80 GiB | Observed | Full cloud stack at idle; monitor swap and disk |
| Expanded | 8 | 16 GiB | 80 GiB | Projected | Full cloud stack with additional headroom |

Ollama remains explicit opt-in. Model weights, context size, quantization, concurrency,
and CPU or GPU mode dominate its capacity requirements, so the selector must calculate
model-specific RAM and disk separately before pulling a model.

## Maintenance

Repeat the measurement after image upgrades, service-topology changes, or material data
growth. Phase 1 must repeat it for each resolved preset and run representative acceptance
traffic before converting idle observations into deployment minimums.

Capture at least six equally spaced samples and record:

```bash
docker compose ps
docker stats --no-stream
docker system df -v
free -b
df -B1 /
```

Do not include unrelated containers in component totals, and do not infer peak capacity
from this idle baseline.
