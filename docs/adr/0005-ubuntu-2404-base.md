# ADR-0005: Ubuntu 24.04 as Base OS

- **Status:** accepted
- **Date:** 2026-03-30

## Context

The lab server needs a stable Linux distribution with long-term support,
good cloud-init integration, and compatibility with Docker, Ollama, and
Python 3.12.

## Decision

Use **Ubuntu 24.04 LTS** as the base operating system.

## Alternatives Considered

| Option | Pros | Cons |
|--------|------|------|
| **Ubuntu 24.04 LTS** | 5-year support (to 2029), Python 3.12 built-in, excellent cloud-init, widest cloud availability | Snap packages, systemd complexity |
| Debian 12 | Minimal, stable, no Snap | Older Python (3.11), less cloud-init polish |
| Fedora | Cutting edge, Python 3.12+ | Short support cycle (13 months), less cloud availability |
| Rocky Linux 9 | RHEL-compatible, enterprise stable | Python 3.9 default, different package manager |
| Alpine | Minimal, fast | musl libc issues, not suited for workstation use |

## Consequences

### Positive

- Python 3.12 available as system package (`python3.12`)
- Excellent cloud-init support across all providers
- Available as default image on Hetzner, AWS, Azure, GCP, DigitalOcean
- LTS support until 2029 — no forced upgrades
- Large community, extensive documentation

### Negative

- Uses `ssh.service` not `sshd.service` (Ubuntu 24.04 change — documented)
- Snap packages can interfere with Docker
- Larger base image than Debian or Alpine

### Known Gotchas

- `systemctl restart sshd` fails — use `systemctl restart ssh`
- `write_files` in cloud-init creates `/home/lab/` as root — must `chown` after
- Docker group doesn't exist until Docker is installed — don't add to groups early
