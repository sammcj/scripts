#!/usr/bin/env python3

# This code is available under the MIT license: https://opensource.org/licenses/MIT

from pathlib import Path
import subprocess
import json
from dataclasses import dataclass
from typing import List, Optional

container_hashes = subprocess.check_output(["docker", "ps", "-q"], text=True)


@dataclass
class Container:
    container_hash: str
    config_hash: str
    project: str
    config: str
    containernum: int
    service: str
    work_dir: Path

    @property
    def name(self) -> str:
        return f"{self.project}_{self.service}_{self.containernum}"


# start gist block
# https://gist.github.com/laundmo/2e2f7314570d2f86a4af8df4b1812b63
def text_width(text: str) -> int:
    return len(max(text.split("\n"), key=len))


def max_text_width(texts: List[str]) -> int:
    return len(max(texts, key=text_width))


def format_table(
    table: List[List[str]],
    headers: Optional[List[str]] = None,
    justify=str.ljust,
) -> str:
    if headers is None:
        headers = [""] * len(table)
    col_l = [max_text_width([headers[i]] + col) for i, col in enumerate(table)]
    output = ""
    if max(headers, key=len) != "":
        output += (
            " | ".join(justify(item, col_l[i]) for i, item in enumerate(headers)) + "\n"
        )
        output += " | ".join("-" * col_l[i] for i, _ in enumerate(table)) + "\n"

    for row in zip(*table):
        output += (
            " | ".join(justify(item, col_l[i]) for i, item in enumerate(row)) + "\n"
        )

    return output


# end gist block

containers: List[Container] = []

for container_hash in container_hashes.strip().split("\n"):
    labels_json = subprocess.check_output(
        ["docker", "inspect", container_hash, "-f", "'{{json .Config.Labels}}'"],
        text=True,
    )
    labels_json = labels_json.strip().rstrip("'").lstrip("'")
    labels = json.loads(labels_json)

    c = Container(
        container_hash,
        labels["com.docker.compose.config-hash"],
        labels["com.docker.compose.project"],
        labels["com.docker.compose.project.config_files"],
        int(labels["com.docker.compose.container-number"]),
        labels["com.docker.compose.service"],
        Path(labels["com.docker.compose.project.working_dir"]),
    )
    containers.append(c)


hashes = subprocess.check_output(
    ["docker-compose", "config", "--hash=*"], text=True
).strip()
confs = [srv_hash.split(" ") for srv_hash in hashes.split("\n")]

tbl: List[List[str]] = []

for service, conf_hash in confs:
    workdir = Path(".")
    service_conts = list(
        filter(
            lambda c: c.work_dir.resolve() == workdir.resolve()
            and c.service == service,
            containers,
        )
    )
    col = [service]
    if len(service_conts) == 0:
        col += ["New container", ""]
    else:
        for result in service_conts:
            if result.config_hash != conf_hash:
                col += ["Restarting container", result.name]
            else:
                col += ["Keeping container", result.name]
    tbl.append(col)

tbl = list(map(list, zip(*tbl)))

print(format_table(tbl, headers=["service", "todo", "container"]))
