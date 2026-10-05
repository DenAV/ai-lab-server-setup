#!/usr/bin/env python3
"""Validate the versioned LiteLLM integration contract."""

from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import Any

try:
    import yaml
except ModuleNotFoundError:
    print("ERROR: PyYAML is required to validate LiteLLM contracts", file=sys.stderr)
    raise SystemExit(2)


ROOT = Path(__file__).resolve().parents[1]
CONTRACT_PATH = ROOT / "config" / "litellm-contracts.yml"
CONFIG_PATH = ROOT / "config" / "litellm-config.yml"
CATALOG_PATH = ROOT / "config" / "components.yml"
COMPOSE_PATH = ROOT / "docker-compose.yml"
CLOUDFLARE_COMPOSE_PATH = ROOT / "compose.traefik-cloudflare.yml"
ENV_PATH = ROOT / ".env.example"
STATUSES = {"conditional", "declared", "deferred", "eligible", "excluded", "verified"}
ACTIVE_STATUSES = {"conditional", "declared", "eligible", "verified"}
ROOT_FIELDS = {
    "schema_version",
    "reviewed_on",
    "verification_status",
    "gateway",
    "endpoints",
    "clients",
    "providers",
    "observability",
    "security_controls",
    "acceptance_tests",
    "sources",
}


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


def validate_status_contract(
    contract: Any,
    field: str,
    test_ids: set[str],
    errors: list[str],
    *,
    endpoint_ids: set[str] | None = None,
) -> None:
    if not isinstance(contract, dict):
        errors.append(f"{field} must be a mapping")
        return
    status = contract.get("status")
    if status not in STATUSES:
        errors.append(f"{field}.status must be one of {sorted(STATUSES)}")
    tests = string_list(contract.get("tests"), f"{field}.tests", errors)
    unknown_tests = set(tests) - test_ids
    if unknown_tests:
        errors.append(f"{field}.tests references unknown tests: {sorted(unknown_tests)}")
    if status in ACTIVE_STATUSES and not tests:
        errors.append(f"{field} requires acceptance tests for status {status}")
    if endpoint_ids is not None:
        endpoints = string_list(contract.get("endpoints"), f"{field}.endpoints", errors)
        unknown_endpoints = set(endpoints) - endpoint_ids
        if unknown_endpoints:
            errors.append(
                f"{field}.endpoints references unknown endpoints: {sorted(unknown_endpoints)}"
            )
        string_list(contract.get("requirements"), f"{field}.requirements", errors)


def read_versions() -> dict[str, str]:
    versions: dict[str, str] = {}
    for line in ENV_PATH.read_text(encoding="utf-8").splitlines():
        match = re.fullmatch(r"([A-Z][A-Z0-9_]*)=(.*)", line)
        if match:
            versions[match.group(1)] = match.group(2)
    return versions


def service_networks(service: dict[str, Any]) -> set[str]:
    networks = service.get("networks") or []
    return set(networks if isinstance(networks, list) else networks)


def service_labels(service: dict[str, Any]) -> dict[str, str]:
    labels = service.get("labels") or {}
    if isinstance(labels, dict):
        return {str(key): str(value) for key, value in labels.items()}
    result: dict[str, str] = {}
    for label in labels:
        key, separator, value = str(label).partition("=")
        if separator:
            result[key] = value
    return result


def main() -> int:
    errors: list[str] = []
    try:
        contract = load_yaml(CONTRACT_PATH)
        runtime_config = load_yaml(CONFIG_PATH)
        catalog = load_yaml(CATALOG_PATH)
        compose = load_yaml(COMPOSE_PATH)
        cloudflare_compose = load_yaml(CLOUDFLARE_COMPOSE_PATH)
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    if set(contract) != ROOT_FIELDS:
        errors.append(
            f"root fields are {sorted(contract)}, expected {sorted(ROOT_FIELDS)}"
        )
    if contract.get("schema_version") != 1:
        errors.append("schema_version must be 1")
    reviewed_on = contract.get("reviewed_on")
    if not isinstance(reviewed_on, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", reviewed_on):
        errors.append("reviewed_on must be an ISO date string")
    if contract.get("verification_status") != "declared-not-executed":
        errors.append("verification_status must remain declared-not-executed until live acceptance")

    tests = contract.get("acceptance_tests")
    if not isinstance(tests, dict) or not tests or any(
        not isinstance(key, str) or not isinstance(value, str) or not value
        for key, value in (tests or {}).items()
    ):
        errors.append("acceptance_tests must map IDs to non-empty descriptions")
        tests = {}
    test_ids = set(tests)

    gateway = contract.get("gateway")
    gateway_fields = {
        "evaluated_version",
        "evaluated_image",
        "internal_base_url",
        "client_auth",
        "admin_auth",
        "provider_credentials",
        "model_aliases",
    }
    if not isinstance(gateway, dict) or set(gateway) != gateway_fields:
        errors.append(f"gateway must contain {sorted(gateway_fields)}")
        gateway = {}
    version = gateway.get("evaluated_version")
    image = gateway.get("evaluated_image")
    if not isinstance(version, str) or not re.fullmatch(r"v\d+\.\d+\.\d+", version):
        errors.append("gateway.evaluated_version must be a stable vMAJOR.MINOR.PATCH tag")
    if not isinstance(image, str) or image.endswith(":latest") or not image.endswith(f":{version}"):
        errors.append("gateway.evaluated_image must use the evaluated non-latest version")
    if gateway.get("internal_base_url") != "http://litellm:4000/v1":
        errors.append("gateway.internal_base_url must use internal service DNS and /v1")
    if gateway.get("client_auth") != "virtual-key":
        errors.append("gateway.client_auth must be virtual-key")
    if gateway.get("admin_auth") != "master-key":
        errors.append("gateway.admin_auth must be master-key")
    if gateway.get("provider_credentials") != "gateway-only":
        errors.append("gateway.provider_credentials must be gateway-only")
    aliases = string_list(gateway.get("model_aliases"), "gateway.model_aliases", errors)
    if set(aliases) != {"lab-chat", "lab-embedding"}:
        errors.append("gateway.model_aliases must define lab-chat and lab-embedding")

    versions = read_versions()
    if versions.get("LITELLM_VERSION") != version:
        errors.append("gateway.evaluated_version must match LITELLM_VERSION in .env.example")

    compose_networks = compose.get("networks") or {}
    for network_name in (
        "litellm-backend",
        "litellm-clients",
        "litellm-ingress",
        "litellm-upstreams",
    ):
        network = compose_networks.get(network_name)
        if not isinstance(network, dict) or network.get("internal") is not True:
            errors.append(f"Compose network {network_name} must be declared internal")
    ingress_ipam = (compose_networks.get("litellm-ingress") or {}).get("ipam") or {}
    if ingress_ipam.get("config") != [{"subnet": "172.30.0.0/29"}]:
        errors.append("Compose network litellm-ingress must use subnet 172.30.0.0/29")

    services = compose.get("services") or {}
    expected_networks = {
        "litellm-db": {"litellm-backend"},
        "litellm": {
            "litellm-backend",
            "litellm-clients",
            "litellm-ingress",
            "litellm-upstreams",
            "traefik-public",
        },
        "traefik": {"litellm-ingress", "traefik-public"},
    }
    for service_name, expected in expected_networks.items():
        actual = service_networks(services.get(service_name) or {})
        if actual != expected:
            errors.append(
                f"Compose service {service_name} networks are {sorted(actual)}, "
                f"expected {sorted(expected)}"
            )
    expected_clients = {"litellm", "n8n", "dify-api", "dify-plugin-daemon", "dify-worker"}
    actual_clients = {
        service_name
        for service_name, service in services.items()
        if "litellm-clients" in service_networks(service)
    }
    if actual_clients != expected_clients:
        errors.append(
            f"litellm-clients members are {sorted(actual_clients)}, "
            f"expected {sorted(expected_clients)}"
        )
    expected_ingress = {"litellm", "traefik"}
    actual_ingress = {
        service_name
        for service_name, service in services.items()
        if "litellm-ingress" in service_networks(service)
    }
    if actual_ingress != expected_ingress:
        errors.append(
            f"litellm-ingress members are {sorted(actual_ingress)}, "
            f"expected {sorted(expected_ingress)}"
        )
    if service_networks(services.get("openclaw") or {}) & {
        "litellm-backend",
        "litellm-clients",
        "litellm-ingress",
        "litellm-upstreams",
    }:
        errors.append("Compose service openclaw must remain outside LiteLLM networks")

    traefik_command = (services.get("traefik") or {}).get("command") or []
    trusted_ips_arg = (
        "--entrypoints.websecure.forwardedheaders.trustedips="
        "${TRAEFIK_FORWARDED_HEADERS_TRUSTED_IPS:-127.0.0.1/32}"
    )
    if trusted_ips_arg not in traefik_command:
        errors.append("Traefik must restrict forwarded headers to configured trusted proxies")
    cloudflare_traefik_command = (
        ((cloudflare_compose.get("services") or {}).get("traefik") or {}).get("command")
        or []
    )
    if trusted_ips_arg not in cloudflare_traefik_command:
        errors.append("Cloudflare Traefik overlay must preserve trusted forwarded headers")

    litellm_environment = (services.get("litellm") or {}).get("environment") or []
    required_litellm_environment = {
        "LITELLM_TRUSTED_PROXY_RANGES=172.30.0.0/29,"
        "${TRAEFIK_FORWARDED_HEADERS_TRUSTED_IPS:-127.0.0.1/32}",
        "LITELLM_MCP_XFF_NUM_TRUSTED_HOPS="
        "${LITELLM_MCP_XFF_NUM_TRUSTED_HOPS:-1}",
        "CHATGPT_TOKEN_DIR=/var/lib/litellm/chatgpt",
        "LITELLM_DISABLE_ENV_CREDENTIAL_LOGIN="
        "${LITELLM_DISABLE_ENV_CREDENTIAL_LOGIN:-false}",
    }
    if not required_litellm_environment.issubset(set(litellm_environment)):
        errors.append("LiteLLM must receive trusted proxy ranges and the MCP trusted hop count")

    labels = service_labels(services.get("litellm") or {})
    if labels.get("traefik.enable") != "false":
        errors.append("LiteLLM Traefik discovery must remain disabled for tunnel-only access")
    if labels.get("traefik.docker.network") != "litellm-ingress":
        errors.append("LiteLLM Traefik routing must use the isolated litellm-ingress network")
    ui_middlewares = labels.get("traefik.http.routers.litellm-ui.middlewares", "")
    if "litellm-ui-allowlist@docker" not in ui_middlewares:
        errors.append("LiteLLM public UI router must use the operator IP allowlist")
    allowlist = labels.get(
        "traefik.http.middlewares.litellm-ui-allowlist.ipallowlist.sourcerange"
    )
    if allowlist != "${LITELLM_UI_ALLOWLIST:-127.0.0.1/32}":
        errors.append("LiteLLM UI allowlist must default to loopback-only access")
    deny_rule = labels.get("traefik.http.routers.litellm-public-deny.rule", "")
    for blocked_path in ("/openapi.json", "/health", "/public/", "chat/completions"):
        if blocked_path not in deny_rule:
            errors.append(f"LiteLLM public deny router must block {blocked_path}")
    if labels.get("traefik.http.routers.litellm-public-deny.priority") != "200":
        errors.append("LiteLLM public deny router must take priority over the UI router")

    runtime_models = runtime_config.get("model_list")
    if not isinstance(runtime_models, list):
        errors.append("litellm-config.model_list must be a list")
        runtime_models = []
    if runtime_models:
        errors.append("litellm-config.model_list must remain empty for GUI-managed models")

    runtime_settings = runtime_config.get("litellm_settings")
    if not isinstance(runtime_settings, dict):
        errors.append("litellm-config.litellm_settings must be a mapping")
    else:
        if runtime_settings.get("turn_off_message_logging") is not True:
            errors.append("litellm-config must set turn_off_message_logging to true")
        if runtime_settings.get("telemetry") is not False:
            errors.append("litellm-config must disable telemetry")
    general_settings = runtime_config.get("general_settings")
    if not isinstance(general_settings, dict):
        errors.append("litellm-config.general_settings must be a mapping")
    else:
        if general_settings.get("master_key") != "os.environ/LITELLM_MASTER_KEY":
            errors.append("litellm-config master key must load from the environment")
        if general_settings.get("disable_env_credential_login") != (
            "os.environ/LITELLM_DISABLE_ENV_CREDENTIAL_LOGIN"
        ):
            errors.append("litellm-config env credential login gate must load from the environment")
        if general_settings.get("store_model_in_db") is not True:
            errors.append("litellm-config must enable database-backed GUI model management")
        if general_settings.get("trusted_proxy_ranges") != "os.environ/LITELLM_TRUSTED_PROXY_RANGES":
            errors.append("litellm-config trusted proxy ranges must load from the environment")
        if general_settings.get("use_x_forwarded_for") is not True:
            errors.append("litellm-config must enable trusted X-Forwarded-For processing")
        if general_settings.get("mcp_trusted_proxy_ranges") != ["172.30.0.0/29"]:
            errors.append("litellm-config must trust only the isolated ingress network for MCP XFF")
        if general_settings.get("mcp_xff_num_trusted_hops") != (
            "os.environ/LITELLM_MCP_XFF_NUM_TRUSTED_HOPS"
        ):
            errors.append("litellm-config MCP trusted hop count must load from the environment")

    endpoints = contract.get("endpoints")
    if not isinstance(endpoints, dict) or not endpoints:
        errors.append("endpoints must be a non-empty mapping")
        endpoints = {}
    endpoint_ids = set(endpoints)
    for endpoint_id, endpoint in endpoints.items():
        field = f"endpoints.{endpoint_id}"
        expected_fields = {"method", "path", "status", "auth", "model_call", "tests", "notes"}
        if not isinstance(endpoint, dict) or set(endpoint) != expected_fields:
            errors.append(f"{field} must contain {sorted(expected_fields)}")
            continue
        validate_status_contract(endpoint, field, test_ids, errors)
        if endpoint["method"] not in {"GET", "POST"}:
            errors.append(f"{field}.method must be GET or POST")
        if not isinstance(endpoint["path"], str) or not endpoint["path"].startswith("/"):
            errors.append(f"{field}.path must be absolute")
        if endpoint["auth"] not in {"master-key", "none", "virtual-key"}:
            errors.append(f"{field}.auth has an unsupported value")
        if not isinstance(endpoint["model_call"], bool):
            errors.append(f"{field}.model_call must be a boolean")
        if not isinstance(endpoint["notes"], str) or not endpoint["notes"]:
            errors.append(f"{field}.notes must be non-empty")

    component_ids = set((catalog.get("components") or {}).keys())
    version_variables = {
        "dify": "DIFY_VERSION",
        "langfuse": "LANGFUSE_VERSION",
        "n8n": "N8N_VERSION",
        "openclaw": "OPENCLAW_VERSION",
    }
    clients = contract.get("clients")
    if not isinstance(clients, dict) or not clients:
        errors.append("clients must be a non-empty mapping")
        clients = {}
    for client_id, client in clients.items():
        field = f"clients.{client_id}"
        expected_fields = {"component", "version", "adapter", "credential", "capabilities"}
        if not isinstance(client, dict) or set(client) != expected_fields:
            errors.append(f"{field} must contain {sorted(expected_fields)}")
            continue
        component = client["component"]
        if component not in component_ids:
            errors.append(f"{field}.component references unknown component {component}")
        expected_version = versions.get(version_variables.get(component, ""))
        if str(client["version"]) != expected_version:
            errors.append(
                f"{field}.version is {client['version']}, expected {expected_version} from .env.example"
            )
        if not isinstance(client["adapter"], str) or not client["adapter"]:
            errors.append(f"{field}.adapter must be non-empty")
        if not isinstance(client["credential"], str) or not client["credential"]:
            errors.append(f"{field}.credential must be non-empty")
        capabilities = client["capabilities"]
        if not isinstance(capabilities, dict) or not capabilities:
            errors.append(f"{field}.capabilities must be a non-empty mapping")
            continue
        for capability_id, capability in capabilities.items():
            capability_fields = {"status", "endpoints", "tests", "requirements"}
            if not isinstance(capability, dict) or set(capability) != capability_fields:
                errors.append(
                    f"{field}.capabilities.{capability_id} must contain "
                    f"{sorted(capability_fields)}"
                )
                continue
            validate_status_contract(
                capability,
                f"{field}.capabilities.{capability_id}",
                test_ids,
                errors,
                endpoint_ids=endpoint_ids,
            )

    providers = contract.get("providers")
    if not isinstance(providers, dict) or not providers:
        errors.append("providers must be a non-empty mapping")
        providers = {}
    for provider_id, provider in providers.items():
        field = f"providers.{provider_id}"
        if not isinstance(provider, dict) or set(provider) != {"auth", "capabilities", "notes"}:
            errors.append(f"{field} must contain auth, capabilities, and notes")
            continue
        if not isinstance(provider["auth"], str) or not provider["auth"]:
            errors.append(f"{field}.auth must be non-empty")
        if not isinstance(provider["notes"], str) or not provider["notes"]:
            errors.append(f"{field}.notes must be non-empty")
        capabilities = provider["capabilities"]
        if not isinstance(capabilities, dict) or not capabilities:
            errors.append(f"{field}.capabilities must be a non-empty mapping")
            continue
        for capability_id, capability in capabilities.items():
            if not isinstance(capability, dict) or set(capability) != {"status", "tests"}:
                errors.append(f"{field}.capabilities.{capability_id} must contain status and tests")
                continue
            validate_status_contract(
                capability, f"{field}.capabilities.{capability_id}", test_ids, errors
            )

    observability = contract.get("observability")
    if not isinstance(observability, dict) or not observability:
        errors.append("observability must be a non-empty mapping")
        observability = {}
    for integration_id, integration in observability.items():
        field = f"observability.{integration_id}"
        expected_fields = {"component", "version", "status", "tests", "reason"}
        if not isinstance(integration, dict) or set(integration) != expected_fields:
            errors.append(f"{field} must contain {sorted(expected_fields)}")
            continue
        validate_status_contract(integration, field, test_ids, errors)
        component = integration["component"]
        if component not in component_ids:
            errors.append(f"{field}.component references unknown component {component}")
        expected_version = versions.get(version_variables.get(component, ""))
        if str(integration["version"]) != expected_version:
            errors.append(f"{field}.version must match .env.example version {expected_version}")
        if not isinstance(integration["reason"], str) or not integration["reason"]:
            errors.append(f"{field}.reason must be non-empty")

    controls = string_list(contract.get("security_controls"), "security_controls", errors)
    if not controls:
        errors.append("security_controls must not be empty")
    if not any("turn_off_message_logging" in control for control in controls):
        errors.append("security_controls must require turn_off_message_logging")
    if "logging-content-redaction" not in test_ids:
        errors.append("acceptance_tests must verify prompt and response redaction")
    model_tests = set((endpoints.get("models") or {}).get("tests") or [])
    if "unauthenticated-model-deny" not in model_tests:
        errors.append("endpoints.models must test unauthenticated access denial")

    sources = contract.get("sources")
    if not isinstance(sources, list) or not sources:
        errors.append("sources must be a non-empty list")
        sources = []
    for index, source in enumerate(sources):
        field = f"sources[{index}]"
        if not isinstance(source, dict) or set(source) != {"title", "url", "accessed"}:
            errors.append(f"{field} must contain title, url, and accessed")
            continue
        if not isinstance(source["title"], str) or not source["title"]:
            errors.append(f"{field}.title must be non-empty")
        if not isinstance(source["url"], str) or not source["url"].startswith("https://"):
            errors.append(f"{field}.url must use HTTPS")
        if source["accessed"] != reviewed_on:
            errors.append(f"{field}.accessed must match reviewed_on")

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print(
        f"LiteLLM contracts valid: {len(clients)} clients, {len(providers)} providers, "
        f"{len(endpoints)} endpoint contracts"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
