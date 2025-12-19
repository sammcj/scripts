#!/usr/bin/env python3
"""
compose-tree: Analyse Docker Compose restart requirements

Shows what containers need restarting and why, including dependency chains.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any

# Global debug flag
DEBUG = False


class Colour:
    """ANSI colour codes for terminal output."""

    RESET = "\033[0m"
    BOLD = "\033[1m"
    DIM = "\033[2m"

    RED = "\033[91m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    BLUE = "\033[94m"
    MAGENTA = "\033[95m"
    CYAN = "\033[96m"

    @classmethod
    def disable(cls) -> None:
        """Disable colours (for non-TTY output)."""
        for attr in dir(cls):
            if attr.isupper() and not attr.startswith("_"):
                setattr(cls, attr, "")


class RestartTrigger(Enum):
    """Reasons why a container needs to be restarted."""

    IMAGE_UPDATED = "IMAGE_UPDATED"
    CONFIG_CHANGED = "CONFIG_CHANGED"
    DEPENDENCY_RESTART = "DEPENDENCY_RESTART"
    NOT_RUNNING = "NOT_RUNNING"
    NOT_CREATED = "NOT_CREATED"


@dataclass
class RestartReason:
    """A single reason for restart with details."""

    trigger: RestartTrigger
    details: list[str] = field(default_factory=list)


@dataclass
class ServiceStatus:
    """Status of a single service."""

    name: str
    needs_restart: bool = False
    reasons: list[RestartReason] = field(default_factory=list)
    dependencies: list[str] = field(default_factory=list)
    dependents: list[str] = field(default_factory=list)
    container_state: str = ""
    exit_code: int | None = None


def run_command(cmd: list[str], cwd: Path | None = None) -> tuple[int, str, str]:
    """Run a command and return exit code, stdout, stderr."""
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            cwd=cwd,
            timeout=60,
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return 1, "", "Command timed out"
    except FileNotFoundError:
        return 1, "", f"Command not found: {cmd[0]}"


def get_compose_config(
    compose_file: Path, project_dir: Path
) -> dict[str, Any] | None:
    """Get the resolved compose configuration as JSON."""
    cmd = ["docker", "compose"]
    if compose_file:
        cmd.extend(["-f", str(compose_file)])
    cmd.extend(["config", "--format", "json"])

    code, stdout, stderr = run_command(cmd, cwd=project_dir)
    if code != 0:
        print(f"{Colour.RED}Error getting compose config:{Colour.RESET} {stderr}")
        return None

    try:
        return json.loads(stdout)
    except json.JSONDecodeError as e:
        print(f"{Colour.RED}Error parsing compose config:{Colour.RESET} {e}")
        return None


def get_compose_ps(
    compose_file: Path, project_dir: Path
) -> list[dict[str, Any]]:
    """Get current container states from docker compose ps."""
    cmd = ["docker", "compose"]
    if compose_file:
        cmd.extend(["-f", str(compose_file)])
    cmd.extend(["ps", "--all", "--format", "json"])

    code, stdout, stderr = run_command(cmd, cwd=project_dir)
    if code != 0:
        return []

    containers = []
    for line in stdout.strip().split("\n"):
        if line:
            try:
                containers.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return containers


def get_container_inspect(container_name: str) -> dict[str, Any] | None:
    """Get detailed container information via docker inspect."""
    cmd = ["docker", "inspect", container_name]
    code, stdout, stderr = run_command(cmd)
    if code != 0:
        return None

    try:
        data = json.loads(stdout)
        return data[0] if data else None
    except (json.JSONDecodeError, IndexError):
        return None


def get_image_id(image_name: str) -> str | None:
    """Get the ID of a local image."""
    cmd = ["docker", "image", "inspect", image_name, "--format", "{{.Id}}"]
    code, stdout, stderr = run_command(cmd)
    if code != 0:
        return None
    return stdout.strip()


def normalise_env_list(env: list[str] | dict[str, str] | None) -> dict[str, str]:
    """Convert environment variables to a normalised dict."""
    if env is None:
        return {}
    if isinstance(env, dict):
        return {str(k): str(v) if v is not None else "" for k, v in env.items()}
    result = {}
    for item in env:
        if "=" in item:
            key, _, value = item.partition("=")
            result[key] = value
        else:
            result[item] = ""
    return result


def normalise_ports(ports: list[Any] | None) -> set[str]:
    """Normalise port mappings to comparable strings."""
    if not ports:
        return set()

    result = set()
    for port in ports:
        if isinstance(port, dict):
            target = port.get("target", "")
            published = port.get("published", "")
            protocol = port.get("protocol", "tcp")
            if published:
                result.add(f"{published}:{target}/{protocol}")
            else:
                result.add(f"{target}/{protocol}")
        else:
            result.add(str(port))
    return result


def normalise_volumes(volumes: list[Any] | None) -> set[str]:
    """Normalise volume mounts to comparable strings."""
    if not volumes:
        return set()

    result = set()
    for vol in volumes:
        if isinstance(vol, dict):
            source = vol.get("source", "")
            target = vol.get("target", "")
            vtype = vol.get("type", "volume")
            result.add(f"{vtype}:{source}:{target}")
        else:
            result.add(str(vol))
    return result


def check_image_changed(
    service_name: str,
    compose_config: dict[str, Any],
    container_info: dict[str, Any] | None,
) -> RestartReason | None:
    """Check if the local image differs from the running container's image."""
    service_cfg = compose_config.get("services", {}).get(service_name, {})
    desired_image = service_cfg.get("image")

    if not desired_image:
        return None

    if not container_info:
        return None

    container_image_id = container_info.get("Image", "")
    local_image_id = get_image_id(desired_image)

    if not local_image_id:
        return None

    if container_image_id != local_image_id:
        return RestartReason(
            trigger=RestartTrigger.IMAGE_UPDATED,
            details=[
                f"Current: {container_image_id[:19]}...",
                f"Available: {local_image_id[:19]}...",
            ],
        )
    return None


def check_config_changed(
    service_name: str,
    compose_config: dict[str, Any],
    container_info: dict[str, Any] | None,
) -> RestartReason | None:
    """Check if the compose config differs from the running container.

    Key insight: Docker Compose only recreates when something SPECIFIED in compose
    differs from container. Extra values in container (from base image, Docker
    defaults) are fine. We check "is compose config satisfied?" not "are they equal?".
    """
    if not container_info:
        return None

    service_cfg = compose_config.get("services", {}).get(service_name, {})
    container_cfg = container_info.get("Config", {})
    host_cfg = container_info.get("HostConfig", {})

    changed_fields = []

    # Check environment: only flag if a var DEFINED IN COMPOSE is missing/different
    desired_env = normalise_env_list(service_cfg.get("environment"))
    current_env = normalise_env_list(container_cfg.get("Env", []))

    for key, desired_val in desired_env.items():
        current_val = current_env.get(key)
        if current_val is None or current_val != desired_val:
            changed_fields.append("environment")
            break

    # Check command - only if explicitly set in compose
    desired_cmd = service_cfg.get("command")
    if desired_cmd is not None:
        current_cmd = container_cfg.get("Cmd")
        if isinstance(desired_cmd, str):
            desired_cmd = desired_cmd.split()
        if current_cmd != desired_cmd:
            changed_fields.append("command")

    # Check entrypoint - only if explicitly set in compose
    desired_entry = service_cfg.get("entrypoint")
    if desired_entry is not None:
        current_entry = container_cfg.get("Entrypoint")
        if isinstance(desired_entry, str):
            desired_entry = [desired_entry]
        if current_entry != desired_entry:
            changed_fields.append("entrypoint")

    # Check working directory - only if explicitly set
    desired_workdir = service_cfg.get("working_dir")
    if desired_workdir:
        current_workdir = container_cfg.get("WorkingDir")
        if desired_workdir != current_workdir:
            changed_fields.append("working_dir")

    # Check user - only if explicitly set
    desired_user = service_cfg.get("user")
    if desired_user is not None:
        current_user = container_cfg.get("User") or ""
        if str(desired_user) != str(current_user):
            changed_fields.append("user")

    # Check labels: only verify labels DEFINED IN COMPOSE exist with correct values
    desired_labels = service_cfg.get("labels", {})
    if isinstance(desired_labels, list):
        desired_labels = dict(item.split("=", 1) for item in desired_labels if "=" in item)
    if desired_labels:
        current_labels = container_cfg.get("Labels", {})
        label_diffs = []
        for key, desired_val in desired_labels.items():
            current_val = current_labels.get(key)
            # Unescape $$ -> $ in desired value (compose escape sequence)
            desired_val_normalised = desired_val.replace("$$", "$") if desired_val else desired_val
            if current_val != desired_val_normalised:
                # Smart diff: show what actually changed with colour highlighting
                def format_label_diff(cur: str | None, new: str | None) -> str:
                    if cur is None:
                        snippet = f"{new[:60]}..." if new and len(new) > 60 else new
                        return f"(missing) → {Colour.GREEN}{snippet}{Colour.RESET}"
                    if new is None:
                        snippet = f"{cur[:60]}..." if len(cur) > 60 else cur
                        return f"{Colour.RED}{snippet}{Colour.RESET} → (removed)"

                    # Find first difference
                    min_len = min(len(cur), len(new))
                    diff_start = 0
                    for i in range(min_len):
                        if cur[i] != new[i]:
                            diff_start = i
                            break
                    else:
                        diff_start = min_len  # Difference is in length

                    # Show context around difference
                    context_before = 15
                    context_after = 30
                    start = max(0, diff_start - context_before)

                    prefix = "..." if start > 0 else ""

                    # Split into common prefix, different part, and suffix
                    common_before = cur[start:diff_start]
                    cur_diff = cur[diff_start:diff_start + context_after]
                    new_diff = new[diff_start:diff_start + context_after]
                    cur_suffix = "..." if diff_start + context_after < len(cur) else ""
                    new_suffix = "..." if diff_start + context_after < len(new) else ""

                    # Format with colours: red for removed, green for added
                    cur_formatted = f"{prefix}{common_before}{Colour.RED}{cur_diff}{Colour.RESET}{cur_suffix}"
                    new_formatted = f"{prefix}{common_before}{Colour.GREEN}{new_diff}{Colour.RESET}{new_suffix}"

                    return f"{cur_formatted} → {new_formatted}"

                label_diffs.append(f"{key}: {format_label_diff(current_val, desired_val_normalised)}")
                if DEBUG:
                    print(f"  [DEBUG] {service_name} label mismatch: {key}")
                    print(f"    compose (normalised): {desired_val_normalised!r}")
                    print(f"    current: {current_val!r}")
        if label_diffs:
            changed_fields.append(("labels", label_diffs))

    # Check ports: verify compose-specified ports are present
    # Normalise to comparable format: "host_port:container_port/protocol"
    desired_ports_raw = service_cfg.get("ports", [])
    if desired_ports_raw:
        current_port_bindings = host_cfg.get("PortBindings", {}) or {}

        # Build lookup of current ports: container_port/proto -> set of host_ports
        current_port_map: dict[str, set[str]] = {}
        for port_proto, bindings in current_port_bindings.items():
            if bindings:
                current_port_map[port_proto] = {b.get("HostPort", "") for b in bindings}

        ports_match = True
        for port in desired_ports_raw:
            if isinstance(port, dict):
                target = port.get("target")
                published = port.get("published")
                protocol = port.get("protocol", "tcp")
            elif isinstance(port, str) and ":" in port:
                # Parse "host:container" or "host:container/proto"
                parts = port.replace("/", ":").split(":")
                published = parts[0] if len(parts) >= 2 else None
                target = parts[1] if len(parts) >= 2 else parts[0]
                protocol = parts[2] if len(parts) >= 3 else "tcp"
            else:
                continue

            if published and target:
                container_port_key = f"{target}/{protocol}"
                current_host_ports = current_port_map.get(container_port_key, set())
                if str(published) not in current_host_ports:
                    ports_match = False
                    break

        if not ports_match:
            changed_fields.append("ports")

    # Check volumes: verify compose-specified mounts are present
    desired_volumes_raw = service_cfg.get("volumes", [])
    if desired_volumes_raw:
        current_mounts = container_info.get("Mounts", [])
        # Build lookup by destination
        current_mount_map = {m.get("Destination"): m for m in current_mounts}

        volumes_match = True
        for vol in desired_volumes_raw:
            if isinstance(vol, dict):
                target = vol.get("target")
                source = vol.get("source")
            elif isinstance(vol, str) and ":" in vol:
                parts = vol.split(":")
                source = parts[0]
                target = parts[1] if len(parts) >= 2 else parts[0]
            else:
                continue

            if target:
                current_mount = current_mount_map.get(target)
                if not current_mount:
                    volumes_match = False
                    break
                # For bind mounts, verify source matches
                if source and current_mount.get("Type") == "bind":
                    if current_mount.get("Source") != source:
                        volumes_match = False
                        break

        if not volumes_match:
            changed_fields.append("volumes")

    # Check networks: only if explicitly specified in compose
    desired_networks = service_cfg.get("networks")
    if desired_networks:
        if isinstance(desired_networks, dict):
            desired_network_names = set(desired_networks.keys())
        elif isinstance(desired_networks, list):
            desired_network_names = set(desired_networks)
        else:
            desired_network_names = set()

        if desired_network_names:
            network_settings = container_info.get("NetworkSettings", {})
            current_networks = set(network_settings.get("Networks", {}).keys())

            # Normalise: strip project prefix, handle full paths
            def normalise_net(name: str) -> str:
                if "/" in name:
                    name = name.split("/")[-1]
                return name

            normalised_desired = {normalise_net(n) for n in desired_network_names}
            # Current networks have project prefix, try to match base names
            normalised_current = set()
            for n in current_networks:
                normalised_current.add(n)
                # Also add without project prefix
                if "_" in n:
                    normalised_current.add(n.split("_", 1)[-1])

            if not normalised_desired.issubset(normalised_current):
                changed_fields.append("networks")

    # Check capabilities: only if explicitly specified, check subset
    # Normalise cap names: Docker uses CAP_X internally, compose often uses X
    def normalise_cap(cap: str) -> str:
        cap = cap.upper()
        if not cap.startswith("CAP_"):
            cap = f"CAP_{cap}"
        return cap

    desired_cap_add = {normalise_cap(c) for c in service_cfg.get("cap_add", [])}
    desired_cap_drop = {normalise_cap(c) for c in service_cfg.get("cap_drop", [])}

    if desired_cap_add or desired_cap_drop:
        current_cap_add = {normalise_cap(c) for c in (host_cfg.get("CapAdd") or [])}
        current_cap_drop = {normalise_cap(c) for c in (host_cfg.get("CapDrop") or [])}
        # Desired caps should be subset of current (container may have more)
        missing_cap_add = desired_cap_add - current_cap_add
        missing_cap_drop = desired_cap_drop - current_cap_drop
        if missing_cap_add:
            if DEBUG:
                print(f"  [DEBUG] {service_name} missing cap_add: {missing_cap_add}")
                print(f"    desired: {desired_cap_add}")
                print(f"    current: {current_cap_add}")
            changed_fields.append("capabilities")
        elif missing_cap_drop:
            if DEBUG:
                print(f"  [DEBUG] {service_name} missing cap_drop: {missing_cap_drop}")
                print(f"    desired: {desired_cap_drop}")
                print(f"    current: {current_cap_drop}")
            changed_fields.append("capabilities")

    # Check resource limits
    desired_deploy = service_cfg.get("deploy", {})
    desired_resources = desired_deploy.get("resources", {})
    if desired_resources:
        limits = desired_resources.get("limits", {})
        if limits.get("memory") or limits.get("cpus"):
            current_memory = host_cfg.get("Memory", 0)
            current_cpus = host_cfg.get("NanoCpus", 0)
            # Basic check - if limits are specified but differ
            if limits.get("memory") and current_memory == 0:
                changed_fields.append("resources")
            elif limits.get("cpus") and current_cpus == 0:
                changed_fields.append("resources")

    if changed_fields:
        # Flatten changed_fields: some are strings, some are (name, [details]) tuples
        details = []
        for item in changed_fields:
            if isinstance(item, tuple):
                field_name, field_details = item
                details.append(f"{field_name}:")
                for detail in field_details:
                    details.append(f"  {detail}")
            else:
                details.append(item)
        return RestartReason(
            trigger=RestartTrigger.CONFIG_CHANGED,
            details=details,
        )
    return None


def build_dependency_graph(
    compose_config: dict[str, Any],
) -> dict[str, list[str]]:
    """Build a mapping of service -> services it depends on."""
    services = compose_config.get("services", {})
    dependencies: dict[str, list[str]] = {}

    for service_name, service_cfg in services.items():
        deps = []

        # Handle depends_on (both list and dict formats)
        depends_on = service_cfg.get("depends_on", {})
        if isinstance(depends_on, list):
            deps.extend(depends_on)
        elif isinstance(depends_on, dict):
            deps.extend(depends_on.keys())

        # Handle links (legacy)
        links = service_cfg.get("links", [])
        for link in links:
            # Links can be "service" or "service:alias"
            dep_service = link.split(":")[0]
            if dep_service not in deps:
                deps.append(dep_service)

        dependencies[service_name] = deps

    return dependencies


def build_dependents_graph(
    dependencies: dict[str, list[str]],
) -> dict[str, list[str]]:
    """Build inverse mapping: service -> services that depend on it."""
    dependents: dict[str, list[str]] = {name: [] for name in dependencies}

    for service, deps in dependencies.items():
        for dep in deps:
            if dep in dependents:
                dependents[dep].append(service)

    return dependents


def propagate_dependency_restarts(
    statuses: dict[str, ServiceStatus],
    dependents_graph: dict[str, list[str]],
) -> None:
    """Mark services as needing restart if their dependencies need restart."""
    # Find all services that need restart for direct reasons
    needs_restart = {
        name for name, status in statuses.items()
        if status.needs_restart and not any(
            r.trigger == RestartTrigger.DEPENDENCY_RESTART for r in status.reasons
        )
    }

    # BFS to propagate to dependents
    to_process = list(needs_restart)
    processed = set()

    while to_process:
        current = to_process.pop(0)
        if current in processed:
            continue
        processed.add(current)

        for dependent in dependents_graph.get(current, []):
            if dependent not in statuses:
                continue

            status = statuses[dependent]

            # Check if already has DEPENDENCY_RESTART reason from this service
            has_dep_reason = any(
                r.trigger == RestartTrigger.DEPENDENCY_RESTART
                for r in status.reasons
            )

            if not has_dep_reason:
                # Add dependency restart reason
                existing_deps = []
                for r in status.reasons:
                    if r.trigger == RestartTrigger.DEPENDENCY_RESTART:
                        existing_deps = r.details
                        break

                if current not in existing_deps:
                    existing_deps.append(current)

                # Find or create the dependency reason
                found = False
                for r in status.reasons:
                    if r.trigger == RestartTrigger.DEPENDENCY_RESTART:
                        if current not in r.details:
                            r.details.append(current)
                        found = True
                        break

                if not found:
                    status.reasons.append(
                        RestartReason(
                            trigger=RestartTrigger.DEPENDENCY_RESTART,
                            details=[current],
                        )
                    )
                status.needs_restart = True

            # Continue propagation
            if dependent not in processed:
                to_process.append(dependent)


def analyse_services(
    compose_file: Path,
    project_dir: Path,
) -> dict[str, ServiceStatus]:
    """Analyse all services and determine restart requirements."""
    config = get_compose_config(compose_file, project_dir)
    if not config:
        return {}

    services = config.get("services", {})
    ps_output = get_compose_ps(compose_file, project_dir)

    # Build lookup of container info by service name
    container_map: dict[str, dict[str, Any]] = {}
    for container in ps_output:
        service = container.get("Service", "")
        if service:
            container_map[service] = container

    # Build dependency graphs
    dependencies = build_dependency_graph(config)
    dependents = build_dependents_graph(dependencies)

    statuses: dict[str, ServiceStatus] = {}

    for service_name in services:
        status = ServiceStatus(
            name=service_name,
            dependencies=dependencies.get(service_name, []),
            dependents=dependents.get(service_name, []),
        )

        container_ps = container_map.get(service_name)

        # Check if container exists and is running
        if not container_ps:
            status.needs_restart = True
            status.reasons.append(
                RestartReason(
                    trigger=RestartTrigger.NOT_CREATED,
                    details=["Container does not exist"],
                )
            )
            status.container_state = "not created"
        else:
            state = container_ps.get("State", "").lower()
            status.container_state = state
            status.exit_code = container_ps.get("ExitCode")

            if state != "running":
                status.needs_restart = True
                exit_info = ""
                if status.exit_code is not None:
                    exit_info = f" (exit code: {status.exit_code})"
                status.reasons.append(
                    RestartReason(
                        trigger=RestartTrigger.NOT_RUNNING,
                        details=[f"State: {state}{exit_info}"],
                    )
                )

            # Get detailed container info for comparisons
            container_name = container_ps.get("Name", "")
            container_info = get_container_inspect(container_name) if container_name else None

            # Check image
            image_reason = check_image_changed(service_name, config, container_info)
            if image_reason:
                status.needs_restart = True
                status.reasons.append(image_reason)

            # Check config
            config_reason = check_config_changed(service_name, config, container_info)
            if config_reason:
                status.needs_restart = True
                status.reasons.append(config_reason)

        statuses[service_name] = status

    # Propagate dependency restarts
    propagate_dependency_restarts(statuses, dependents)

    return statuses


def format_trigger(trigger: RestartTrigger) -> str:
    """Format a trigger with colour."""
    colours = {
        RestartTrigger.IMAGE_UPDATED: Colour.MAGENTA,
        RestartTrigger.CONFIG_CHANGED: Colour.YELLOW,
        RestartTrigger.DEPENDENCY_RESTART: Colour.CYAN,
        RestartTrigger.NOT_RUNNING: Colour.RED,
        RestartTrigger.NOT_CREATED: Colour.RED,
    }
    colour = colours.get(trigger, "")
    return f"{colour}{trigger.value}{Colour.RESET}"


def print_tree_output(statuses: dict[str, ServiceStatus]) -> None:
    """Print the analysis results as a tree."""
    need_restart = {name: s for name, s in statuses.items() if s.needs_restart}
    no_restart = {name: s for name, s in statuses.items() if not s.needs_restart}

    print(f"\n{Colour.BOLD}compose-tree:{Colour.RESET} Analysed {len(statuses)} services\n")

    if need_restart:
        print(f"{Colour.RED}{Colour.BOLD}Restart Required ({len(need_restart)} services):{Colour.RESET}\n")

        sorted_services = sorted(need_restart.keys())
        for i, name in enumerate(sorted_services):
            status = need_restart[name]
            is_last = i == len(sorted_services) - 1
            prefix = "└── " if is_last else "├── "
            child_prefix = "    " if is_last else "│   "

            # Service name with triggers
            triggers = [format_trigger(r.trigger) for r in status.reasons]
            print(f"{prefix}{Colour.BOLD}{name}{Colour.RESET} [{', '.join(triggers)}]")

            # Details for each reason
            for j, reason in enumerate(status.reasons):
                is_last_reason = j == len(status.reasons) - 1 and not status.dependents

                for k, detail in enumerate(reason.details):
                    is_last_detail = k == len(reason.details) - 1
                    detail_prefix = "└── " if is_last_detail and is_last_reason else "├── "
                    print(f"{child_prefix}{detail_prefix}{Colour.DIM}{detail}{Colour.RESET}")

            # Show dependents that will be triggered
            triggered_dependents = [
                d for d in status.dependents
                if d in need_restart and any(
                    r.trigger == RestartTrigger.DEPENDENCY_RESTART and name in r.details
                    for r in need_restart[d].reasons
                )
            ]
            if triggered_dependents:
                print(f"{child_prefix}└── {Colour.CYAN}Triggers restart of:{Colour.RESET}")
                for k, dep in enumerate(sorted(triggered_dependents)):
                    dep_prefix = "    └── " if k == len(triggered_dependents) - 1 else "    ├── "
                    print(f"{child_prefix}{dep_prefix}{dep}")

            print()

    if no_restart:
        print(f"{Colour.GREEN}{Colour.BOLD}No restart required ({len(no_restart)} services):{Colour.RESET}")
        services_list = ", ".join(sorted(no_restart.keys()))
        print(f"  {Colour.DIM}{services_list}{Colour.RESET}\n")


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Analyse Docker Compose restart requirements",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                          # Analyse docker-compose.yaml in current dir
  %(prog)s -f compose.yaml          # Analyse specific file
  %(prog)s -f docker-compose.yaml --no-colour  # Plain text output
        """,
    )
    parser.add_argument(
        "-f", "--file",
        type=Path,
        help="Path to docker-compose file (default: docker-compose.yaml)",
    )
    parser.add_argument(
        "--no-colour", "--no-color",
        action="store_true",
        help="Disable coloured output",
    )
    parser.add_argument(
        "-q", "--quiet",
        action="store_true",
        help="Only show services that need restart",
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Show debug info for mismatches",
    )

    args = parser.parse_args()

    # Set global debug flag
    global DEBUG
    DEBUG = args.debug

    # Disable colours if requested or not a TTY
    if args.no_colour or not sys.stdout.isatty():
        Colour.disable()

    # Determine compose file and project directory
    compose_file = args.file
    if compose_file:
        compose_file = compose_file.resolve()
        project_dir = compose_file.parent
    else:
        project_dir = Path.cwd()
        # Try common names
        for name in ["docker-compose.yaml", "docker-compose.yml", "compose.yaml", "compose.yml"]:
            candidate = project_dir / name
            if candidate.exists():
                compose_file = candidate
                break

    if not compose_file or not compose_file.exists():
        print(f"{Colour.RED}Error:{Colour.RESET} No compose file found", file=sys.stderr)
        return 1

    # Analyse services
    statuses = analyse_services(compose_file, project_dir)
    if not statuses:
        print(f"{Colour.RED}Error:{Colour.RESET} No services found or could not parse compose file", file=sys.stderr)
        return 1

    # Output results
    if args.quiet:
        need_restart = [name for name, s in statuses.items() if s.needs_restart]
        if need_restart:
            for name in sorted(need_restart):
                print(name)
    else:
        print_tree_output(statuses)

    # Exit with 0 if nothing needs restart, 1 otherwise
    return 1 if any(s.needs_restart for s in statuses.values()) else 0


if __name__ == "__main__":
    sys.exit(main())
