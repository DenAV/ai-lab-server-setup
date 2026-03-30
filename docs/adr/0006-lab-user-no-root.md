# ADR-0006: Dedicated Lab User, No Root SSH

- **Status:** accepted
- **Date:** 2026-03-30

## Context

Cloud providers inject SSH keys into the `root` user. For security, we need
to decide how users access the server after provisioning.

## Decision

Create a dedicated **`lab` user** with passwordless sudo. Disable root
SSH login after copying the SSH key to the lab user.

## Alternatives Considered

| Option | Pros | Cons |
|--------|------|------|
| **Dedicated lab user + disable root** | Least privilege, audit trail, standard security practice | Extra setup step, must copy SSH keys |
| Root only | Simple, no user management | OWASP violation, no audit trail, accidental damage |
| Cloud default user (`ubuntu`) | Already exists on Ubuntu images | Name varies by provider (`ec2-user`, `azureuser`), not portable |
| Multiple users | Per-person accountability | Overkill for disposable lab VMs |

## Consequences

### Positive

- Root SSH disabled — reduced attack surface
- `lab` user has sudo for administrative tasks
- Consistent username across all providers (`lab`)
- SSH key copied automatically from root

### Negative

- Extra provisioning step (user creation, key copy)
- Must verify SSH key copy before disabling root (risk of lockout)
- `su - lab` resolves `~` to root's home — must use absolute paths

### Mitigations

- `setup.sh` prints WARNING before disabling root
- SSH key copy happens before SSH hardening
- cloud-init `users` module creates the user with the SSH key directly
