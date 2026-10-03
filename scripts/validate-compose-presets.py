#!/usr/bin/env python3
"""Validate resolved Docker Compose services for catalog presets."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path
from typing import Any

try:
    import yaml
except ModuleNotFoundError:
    print("ERROR: PyYAML is required to validate Compose presets", file=sys.stderr)
    raise SystemExit(2)


ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "config" / "components.yml"
ENV_PATH = ROOT / ".env.example"


def load_catalog() -> dict[str, Any]:
    try:
        catalog = yaml.safe_load(CATALOG_PATH.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError) as exc:
        raise ValueError(f"cannot read config/components.yml: {exc}") from exc
    if not isinstance(catalog, dict):
        raise ValueError("config/components.yml must contain a mapping")
    return catalog


def resolve_services(compose_files: list[str], profiles: list[str]) -> set[str]:
    command = ["docker", "compose", "--env-file", str(ENV_PATH)]
    for compose_file in compose_files:
        command.extend(["-f", str(ROOT / compose_file)])
    for profile in profiles:
        command.extend(["--profile", profile])
    command.extend(["config", "--services"])
    environment = os.environ.copy()
    environment["CLOUDFLARE_DNS_API_TOKEN_FILE"] = "/dev/null"
    result = subprocess.run(
        command,
        cwd=ROOT,
        env=environment,
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        raise RuntimeError(f"Docker Compose resolution failed: {detail}")
    return {line for line in result.stdout.splitlines() if line}


def main() -> int:
    try:
        catalog = load_catalog()
        compose_files = catalog["compose_files"]
        components = catalog["components"]
        presets = catalog["presets"]
    except (KeyError, TypeError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    required_components = {
        component_id
        for component_id, component in components.items()
        if component["required"]
    }
    required_services = {
        service
        for component_id in required_components
        for service in components[component_id]["services"]
    }
    base_compose_files = ["docker-compose.yml"]

    errors: list[str] = []
    try:
        default_services = resolve_services(base_compose_files, [])
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    if default_services != required_services:
        errors.append(
            f"default services are {sorted(default_services)}, expected {sorted(required_services)}"
        )

    for preset_id, preset in presets.items():
        selected = set(preset["components"])
        profiles = sorted(
            component["profile"]
            for component_id, component in components.items()
            if component_id in selected and component["profile"] is not None
        )
        expected = {
            service
            for component_id in selected
            for service in components[component_id]["services"]
        }
        try:
            actual = resolve_services(base_compose_files, profiles)
        except RuntimeError as exc:
            errors.append(f"{preset_id}: {exc}")
            continue
        if actual != expected:
            errors.append(
                f"{preset_id} resolves {sorted(actual)}, expected {sorted(expected)}"
            )

    overlay_cases = {
        "workers overlay": (
            ["docker-compose.yml", "docker-compose.workers.yml"],
            ["n8n", "ffmpeg-worker"],
            {"traefik", "n8n", "ffmpeg-worker"},
        ),
        "OpenClaw overlay": (
            ["docker-compose.yml", "compose.openclaw-cli.yml"],
            ["openclaw"],
            {"traefik", "openclaw"},
        ),
        "Cloudflare DNS overlay": (
            ["docker-compose.yml", "compose.traefik-cloudflare.yml"],
            [],
            {"traefik"},
        ),
    }
    for case_id, (case_files, case_profiles, expected) in overlay_cases.items():
        try:
            actual = resolve_services(case_files, case_profiles)
        except RuntimeError as exc:
            errors.append(f"{case_id}: {exc}")
            continue
        if actual != expected:
            errors.append(f"{case_id} resolves {sorted(actual)}, expected {sorted(expected)}")

    expected_all = {
        service for component in components.values() for service in component["services"]
    }
    try:
        actual_all = resolve_services(compose_files, ["*"])
    except RuntimeError as exc:
        errors.append(f"all profiles: {exc}")
    else:
        if actual_all != expected_all:
            errors.append(
                f"all profiles resolve {sorted(actual_all)}, expected {sorted(expected_all)}"
            )

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print(
        f"Compose presets valid: default plus {len(presets)} presets, "
        f"{len(overlay_cases)} overlays, {len(expected_all)} managed services"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
