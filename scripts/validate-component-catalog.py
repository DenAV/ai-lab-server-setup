#!/usr/bin/env python3
"""Validate the component catalog against repository Compose definitions."""

from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import Any

try:
    import yaml
except ModuleNotFoundError:
    print("ERROR: PyYAML is required to validate the component catalog", file=sys.stderr)
    raise SystemExit(2)


ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "config" / "components.yml"
COMPONENT_FIELDS = {
    "description",
    "required",
    "services",
    "compose_files",
    "profile",
    "dependencies",
    "conflicts",
    "networks",
    "storage",
    "routes",
    "secrets",
    "health_checks",
    "host_prerequisites",
}
REQUIRED_COMPOSE_FILES = {
    "compose.openclaw-cli.yml",
    "docker-compose.workers.yml",
    "docker-compose.yml",
}
STORAGE_FIELDS = {
    "type",
    "compose_file",
    "source",
    "target",
    "read_only",
    "backup",
    "sensitive",
}
BACKUP_CLASSES = {
    "none",
    "recommended",
    "reconstructible",
    "repository",
    "required",
    "unresolved",
}
ENV_REFERENCE = re.compile(r"\$\{([A-Z][A-Z0-9_]*)")
SECRET_VARIABLE = re.compile(r"PASSWORD|SECRET|TOKEN|KEY|SALT")


def load_yaml(path: Path) -> dict[str, Any]:
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError) as exc:
        raise ValueError(f"cannot read {path.relative_to(ROOT)}: {exc}") from exc
    if not isinstance(data, dict):
        raise ValueError(f"{path.relative_to(ROOT)} must contain a mapping")
    return data


def string_list(value: Any, field: str, errors: list[str]) -> list[str]:
    if not isinstance(value, list) or any(not isinstance(item, str) for item in value):
        errors.append(f"{field} must be a list of strings")
        return []
    if len(value) != len(set(value)):
        errors.append(f"{field} contains duplicate values")
    return value


def mount_record(entry: Any, filename: str) -> tuple[str, str, str, bool] | None:
    if isinstance(entry, str):
        parts = entry.split(":")
        if len(parts) >= 2:
            options = parts[2].split(",") if len(parts) >= 3 else []
            return filename, parts[0], parts[1], "ro" in options
        return None
    if isinstance(entry, dict):
        source = entry.get("source")
        target = entry.get("target")
        if isinstance(source, str) and isinstance(target, str):
            return filename, source, target, bool(entry.get("read_only", False))
    return None


def env_references(value: Any) -> set[str]:
    if isinstance(value, str):
        return set(ENV_REFERENCE.findall(value))
    if isinstance(value, list):
        return set().union(*(env_references(item) for item in value))
    if isinstance(value, dict):
        return set().union(*(env_references(item) for item in value.values()))
    return set()


def main() -> int:
    errors: list[str] = []
    try:
        catalog = load_yaml(CATALOG_PATH)
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    if catalog.get("schema_version") != 1:
        errors.append("schema_version must be 1")

    compose_files = string_list(catalog.get("compose_files"), "compose_files", errors)
    if set(compose_files) != REQUIRED_COMPOSE_FILES:
        errors.append(
            f"compose_files must be exactly {sorted(REQUIRED_COMPOSE_FILES)}"
        )
    prerequisites = catalog.get("host_prerequisites")
    components = catalog.get("components")
    if not isinstance(prerequisites, dict) or any(
        not isinstance(key, str) or not isinstance(value, str)
        for key, value in (prerequisites or {}).items()
    ):
        errors.append("host_prerequisites must map IDs to descriptions")
        prerequisites = {}
    if not isinstance(components, dict) or not components:
        errors.append("components must be a non-empty mapping")
        components = {}

    compose_services: dict[str, dict[str, Any]] = {}
    service_files: dict[str, set[str]] = {}
    declared_volumes: set[str] = set()
    declared_networks: set[str] = set()
    for filename in compose_files:
        path = ROOT / filename
        if not path.is_file():
            errors.append(f"compose file does not exist: {filename}")
            continue
        try:
            document = load_yaml(path)
        except ValueError as exc:
            errors.append(str(exc))
            continue
        declared_volumes.update((document.get("volumes") or {}).keys())
        declared_networks.update((document.get("networks") or {}).keys())
        for service_name, config in (document.get("services") or {}).items():
            if not isinstance(config, dict):
                errors.append(f"{filename}: service {service_name} must be a mapping")
                continue
            aggregate = compose_services.setdefault(
                service_name,
                {
                    "profiles": set(),
                    "networks": set(),
                    "mounts": set(),
                    "health": False,
                    "env_references": set(),
                },
            )
            aggregate["profiles"].update(config.get("profiles") or [])
            networks = config.get("networks") or []
            aggregate["networks"].update(networks.keys() if isinstance(networks, dict) else networks)
            for volume in config.get("volumes") or []:
                record = mount_record(volume, filename)
                if record:
                    aggregate["mounts"].add(record)
            aggregate["health"] = aggregate["health"] or "healthcheck" in config
            aggregate["env_references"].update(env_references(config))
            service_files.setdefault(service_name, set()).add(filename)

    component_ids = set(components)
    owned_services: dict[str, str] = {}
    catalog_volumes: set[str] = set()
    catalog_networks: set[str] = set()
    required_components: set[str] = set()
    required_dependency_graph: dict[str, set[str]] = {}

    for component_id, component in components.items():
        prefix = f"components.{component_id}"
        if not isinstance(component_id, str) or not isinstance(component, dict):
            errors.append(f"{prefix} must be a mapping")
            continue
        missing = COMPONENT_FIELDS - set(component)
        extra = set(component) - COMPONENT_FIELDS
        if missing:
            errors.append(f"{prefix} missing fields: {', '.join(sorted(missing))}")
        if extra:
            errors.append(f"{prefix} has unknown fields: {', '.join(sorted(extra))}")
        if not isinstance(component.get("description"), str) or not component.get("description"):
            errors.append(f"{prefix}.description must be a non-empty string")
        if not isinstance(component.get("required"), bool):
            errors.append(f"{prefix}.required must be a boolean")
        elif component["required"]:
            required_components.add(component_id)

        services = string_list(component.get("services"), f"{prefix}.services", errors)
        files = string_list(component.get("compose_files"), f"{prefix}.compose_files", errors)
        networks = string_list(component.get("networks"), f"{prefix}.networks", errors)
        health_checks = string_list(
            component.get("health_checks"), f"{prefix}.health_checks", errors
        )
        catalog_networks.update(networks)
        for service in services:
            if service in owned_services:
                errors.append(
                    f"service {service} is owned by both {owned_services[service]} and {component_id}"
                )
            owned_services[service] = component_id

        expected_files = set().union(*(service_files.get(service, set()) for service in services))
        if set(files) != expected_files:
            errors.append(
                f"{prefix}.compose_files is {sorted(files)}, expected {sorted(expected_files)}"
            )
        expected_networks = set().union(
            *(compose_services.get(service, {}).get("networks", set()) for service in services)
        )
        if set(networks) != expected_networks:
            errors.append(
                f"{prefix}.networks is {sorted(networks)}, expected {sorted(expected_networks)}"
            )
        expected_health = {
            service
            for service in services
            if compose_services.get(service, {}).get("health", False)
        }
        if set(health_checks) != expected_health:
            errors.append(
                f"{prefix}.health_checks is {sorted(health_checks)}, "
                f"expected {sorted(expected_health)}"
            )

        profile = component.get("profile")
        if profile is not None and not isinstance(profile, str):
            errors.append(f"{prefix}.profile must be a string or null")
        actual_profiles = set().union(
            *(compose_services.get(service, {}).get("profiles", set()) for service in services)
        )
        expected_profiles = {profile} if profile else set()
        if actual_profiles != expected_profiles:
            errors.append(
                f"{prefix}.profile is {profile!r}, Compose profiles are {sorted(actual_profiles)}"
            )
        if component.get("required") and profile:
            errors.append(f"{prefix} is required and cannot have an optional profile")

        dependencies = component.get("dependencies")
        if not isinstance(dependencies, dict) or set(dependencies) != {"required", "optional"}:
            errors.append(f"{prefix}.dependencies must contain required and optional lists")
            dependencies = {"required": [], "optional": []}
        required_deps = string_list(
            dependencies.get("required"), f"{prefix}.dependencies.required", errors
        )
        optional_deps = string_list(
            dependencies.get("optional"), f"{prefix}.dependencies.optional", errors
        )
        conflicts = string_list(component.get("conflicts"), f"{prefix}.conflicts", errors)
        for relation in required_deps + optional_deps + conflicts:
            if relation not in component_ids:
                errors.append(f"{prefix} references unknown component {relation}")
            if relation == component_id:
                errors.append(f"{prefix} cannot reference itself")
        if set(required_deps) & set(optional_deps):
            errors.append(f"{prefix} repeats a dependency as required and optional")
        if (set(required_deps) | set(optional_deps)) & set(conflicts):
            errors.append(f"{prefix} conflicts with one of its dependencies")
        required_dependency_graph[component_id] = set(required_deps)

        string_list(component.get("routes"), f"{prefix}.routes", errors)
        secrets = string_list(component.get("secrets"), f"{prefix}.secrets", errors)
        referenced_variables = set().union(
            *(
                compose_services.get(service, {}).get("env_references", set())
                for service in services
            )
        )
        for secret in secrets:
            if not re.fullmatch(r"[A-Z][A-Z0-9_]*", secret):
                errors.append(f"{prefix}.secrets contains invalid variable name {secret}")
            elif secret not in referenced_variables:
                errors.append(f"{prefix}.secrets references unused Compose variable {secret}")
        expected_secrets = {
            variable for variable in referenced_variables if SECRET_VARIABLE.search(variable)
        }
        if set(secrets) != expected_secrets:
            errors.append(
                f"{prefix}.secrets is {sorted(secrets)}, expected {sorted(expected_secrets)}"
            )

        component_prerequisites = component.get("host_prerequisites")
        if not isinstance(component_prerequisites, dict) or set(component_prerequisites) != {
            "required",
            "conditional",
        }:
            errors.append(
                f"{prefix}.host_prerequisites must contain required and conditional"
            )
            component_prerequisites = {"required": [], "conditional": {}}
        prerequisite_ids = string_list(
            component_prerequisites.get("required"),
            f"{prefix}.host_prerequisites.required",
            errors,
        )
        conditional_prerequisites = component_prerequisites.get("conditional")
        if not isinstance(conditional_prerequisites, dict):
            errors.append(f"{prefix}.host_prerequisites.conditional must be a mapping")
            conditional_prerequisites = {}
        for filename, values in conditional_prerequisites.items():
            if filename not in files:
                errors.append(
                    f"{prefix}.host_prerequisites.conditional references unused {filename}"
                )
            prerequisite_ids.extend(
                string_list(
                    values,
                    f"{prefix}.host_prerequisites.conditional.{filename}",
                    errors,
                )
            )
        for prerequisite in prerequisite_ids:
            if prerequisite not in prerequisites:
                errors.append(f"{prefix} references unknown host prerequisite {prerequisite}")

        storage = component.get("storage")
        if not isinstance(storage, list):
            errors.append(f"{prefix}.storage must be a list")
            storage = []
        storage_records: set[tuple[str, str, str, bool]] = set()
        for index, item in enumerate(storage):
            storage_prefix = f"{prefix}.storage[{index}]"
            if not isinstance(item, dict) or set(item) != STORAGE_FIELDS:
                errors.append(f"{storage_prefix} must contain {', '.join(sorted(STORAGE_FIELDS))}")
                continue
            if item["type"] not in {"bind", "volume"}:
                errors.append(f"{storage_prefix}.type must be bind or volume")
            if item["compose_file"] not in files:
                errors.append(f"{storage_prefix}.compose_file is not used by the component")
            if not isinstance(item["source"], str) or not isinstance(item["target"], str):
                errors.append(f"{storage_prefix} source and target must be strings")
                continue
            if not isinstance(item["read_only"], bool):
                errors.append(f"{storage_prefix}.read_only must be a boolean")
                continue
            if item["backup"] not in BACKUP_CLASSES:
                errors.append(f"{storage_prefix}.backup has an unsupported value")
            if not isinstance(item["sensitive"], bool):
                errors.append(f"{storage_prefix}.sensitive must be a boolean")
            record = (
                item["compose_file"],
                item["source"],
                item["target"],
                item["read_only"],
            )
            if record in storage_records:
                errors.append(
                    f"{storage_prefix} duplicates mount {record[1]}:{record[2]} in {record[0]}"
                )
            storage_records.add(record)
            if item["type"] == "volume":
                catalog_volumes.add(item["source"])
        expected_mounts = set().union(
            *(compose_services.get(service, {}).get("mounts", set()) for service in services)
        )
        if storage_records != expected_mounts:
            errors.append(
                f"{prefix}.storage mounts are {sorted(storage_records)}, "
                f"expected {sorted(expected_mounts)}"
            )

    if set(owned_services) != set(compose_services):
        missing = set(compose_services) - set(owned_services)
        extra = set(owned_services) - set(compose_services)
        if missing:
            errors.append(f"Compose services missing from catalog: {', '.join(sorted(missing))}")
        if extra:
            errors.append(f"catalog services missing from Compose: {', '.join(sorted(extra))}")
    if catalog_volumes != declared_volumes:
        errors.append(
            f"catalog volumes are {sorted(catalog_volumes)}, expected {sorted(declared_volumes)}"
        )
    if catalog_networks != declared_networks:
        errors.append(
            f"catalog networks are {sorted(catalog_networks)}, expected {sorted(declared_networks)}"
        )
    if required_components != {"traefik"}:
        errors.append("traefik must be the only required component")

    visited: set[str] = set()
    active: set[str] = set()

    def visit(component_id: str) -> None:
        if component_id in active:
            errors.append(f"required dependency cycle includes {component_id}")
            return
        if component_id in visited:
            return
        active.add(component_id)
        for dependency in required_dependency_graph.get(component_id, set()):
            if dependency in required_dependency_graph:
                visit(dependency)
        active.remove(component_id)
        visited.add(component_id)

    for component_id in required_dependency_graph:
        visit(component_id)

    for component_id, component in components.items():
        if not isinstance(component, dict):
            continue
        for conflict in component.get("conflicts") or []:
            other = components.get(conflict)
            if isinstance(other, dict) and component_id not in (other.get("conflicts") or []):
                errors.append(f"conflict between {component_id} and {conflict} must be symmetric")

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print(
        f"Component catalog valid: {len(components)} components, "
        f"{len(compose_services)} services, {len(declared_volumes)} volumes"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
