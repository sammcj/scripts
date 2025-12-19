# compose-tree

Analyse Docker Compose services to see **what** needs restarting and **why** before running `docker compose up -d`.

## Usage

```bash
# Analyse docker-compose.yaml in current directory
./compose_tree.py

# Analyse a specific file
./compose_tree.py -f /path/to/docker-compose.yaml

# Plain text output (no colours)
./compose_tree.py --no-colour

# Quiet mode - just list service names
./compose_tree.py -q

# Debug mode - show detailed comparison info
./compose_tree.py --debug
```

## What It Detects

| Trigger              | Description                                                    |
|----------------------|----------------------------------------------------------------|
| `IMAGE_UPDATED`      | Local image differs from container's image                     |
| `CONFIG_CHANGED`     | Environment, volumes, ports, networks, or other config changed |
| `DEPENDENCY_RESTART` | A service this one `depends_on` needs restarting               |
| `NOT_RUNNING`        | Container is stopped or exited                                 |
| `NOT_CREATED`        | Container doesn't exist                                        |

## Example Output

```
compose-tree: Analysed 12 services

Restart Required (4 services):

├── llamacpp [IMAGE_UPDATED]
│   ├── Current: sha256:abc123...
│   ├── Available: sha256:def456...
│   └── Triggers restart of:
│       ├── open-webui (depends_on)
│       └── pipelines (depends_on → open-webui)

├── open-webui [CONFIG_CHANGED, DEPENDENCY_RESTART]
│   ├── labels:
│   ├──   traefik.http.routers.rule: ...Host(`old.example`) → ...Host(`new.example`)
│   ├── llamacpp
│   └── Triggers restart of:
│       └── pipelines

├── pipelines [DEPENDENCY_RESTART]
│   └── llamacpp

└── redis [NOT_RUNNING]
    └── State: exited (exit code: 137)

No restart required (8 services):
  plex, sonarr, radarr, prowlarr, transmission, nzbget, tautulli, overseerr
```

## Config Fields Compared

- `environment` - Environment variables
- `command` - Override command
- `entrypoint` - Override entrypoint
- `working_dir` - Working directory
- `user` - User to run as
- `labels` - Container labels (with coloured inline diff showing what changed)
- `ports` - Port mappings
- `volumes` - Volume mounts
- `networks` - Network attachments
- `capabilities` - cap_add/cap_drop
- `resources` - Memory/CPU limits

For label changes, the output shows a smart diff with context around the difference, highlighted in red (old) and green (new).

## Requirements

- Python 3.12+
- Docker with `docker compose` v2
- No external Python dependencies (uses stdlib only)

## Testing

A test compose file is included for development:

```bash
cd test
docker compose up -d
python3 ../compose_tree.py
```

## Exit Codes

- `0` - No services need restart
- `1` - One or more services need restart (or error)
