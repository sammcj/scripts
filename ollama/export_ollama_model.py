import os
import json
import zipfile
import argparse
import subprocess
from pathlib import Path

# Example remote sync model usage:
# python export_ollama_model.py --remote-host <username>@<hostname> <model_name> <model_tag>
# e.g:
# python export_ollama_model.py --remote-host sam@server technobyte/c4ai-command-r7b-12-2024 q5_k_M

def split_model_name(model_name):
    """Split a model name that might include repository (e.g., 'technobyte/model' -> ('technobyte', 'model'))"""
    if '/' in model_name:
        return model_name.split('/', 1)
    return None, model_name

def get_model_manifest_path(ollama_path, registry, repository, model_name, model_tag):
    # If model_name contains repository info, split it
    repo_from_name, base_model_name = split_model_name(model_name)
    if repo_from_name:
        repository = repo_from_name
        model_name = base_model_name

    # Try all possible path combinations
    paths = [
        # Direct path (no library)
        Path(ollama_path) / "models/manifests" / registry / repository / model_name / model_tag,
        # With library before repository
        Path(ollama_path) / "models/manifests" / registry / "library" / repository / model_name / model_tag,
        # With library after registry, before model
        Path(ollama_path) / "models/manifests" / registry / "library" / model_name / model_tag,
        # Repository as part of model name (no library)
        Path(ollama_path) / "models/manifests" / registry / f"{repository}/{model_name}" / model_tag,
    ]

    # Debug: Print all paths being checked
    print("Checking the following paths:")
    for path in paths:
        print(f"- {path} {'(exists)' if path.exists() else '(not found)'}")

    # Return the first path that exists
    for path in paths:
        if path.exists():
            return path

    # If no path exists, return the first path for error handling
    return paths[0]

def get_blob_file_path(ollama_path, digest):
    return Path(ollama_path) / "models/blobs" / f"sha256-{digest.split(':')[1]}"

def list_models(ollama_path):
    """List all models in the given Ollama path."""
    models = []
    manifests_path = Path(ollama_path) / "models/manifests"
    if not manifests_path.exists():
        return models

    for registry_dir in manifests_path.iterdir():
        if not registry_dir.is_dir():
            continue

        # Handle different repository directories
        for repo_dir in registry_dir.iterdir():
            if not repo_dir.is_dir():
                continue

            # Handle library directory specially
            if repo_dir.name == 'library':
                # List models directly in library
                for model_dir in repo_dir.iterdir():
                    if model_dir.is_dir():
                        for tag_dir in model_dir.iterdir():
                            if tag_dir.is_dir():
                                models.append((model_dir.name, tag_dir.name))
            else:
                # For non-library repositories
                for model_dir in repo_dir.iterdir():
                    if model_dir.is_dir():
                        for tag_dir in model_dir.iterdir():
                            if tag_dir.is_dir():
                                models.append((f"{repo_dir.name}/{model_dir.name}", tag_dir.name))

    return sorted(set(models))  # Remove duplicates and sort

def read_manifest(manifest_path):
    with open(manifest_path, 'r') as file:
        return json.load(file)

def rsync_model(source_ollama_path, dest_ollama_path, registry, repository, model_name, model_tag, remote_host, pull=False):
    # Store current directory
    original_dir = os.getcwd()

    try:
        # Determine model paths
        model_path = f"models/manifests/{registry}/{repository}/{model_name}/{model_tag}"
        blobs_path = "models/blobs"

        if pull:
            # For pull mode, check if the model exists on the remote
            print(f"Checking for model on remote host {remote_host}...")
            check_cmd = f"ssh {remote_host} '[ -d {dest_ollama_path}/{model_path} ]'"
            result = subprocess.run(check_cmd, shell=True)
            if result.returncode != 0:
                raise FileNotFoundError(f"Could not find model manifest on remote host for {model_name}:{model_tag}")
            print("Model found on remote host.")
        else:
            # For push mode, check local manifest
            manifest_path = get_model_manifest_path(source_ollama_path, registry, repository, model_name, model_tag)
            if not manifest_path.exists():
                raise FileNotFoundError(f"Could not find model manifest in any of the expected locations for {model_name}:{model_tag}")
            manifest = read_manifest(manifest_path)

        # Change to appropriate directory
        os.chdir(source_ollama_path if not pull else '.')

        # Construct rsync command
        rsync_cmd = [
            'rsync',
            '--progress',  # show progress during transfer
            '--partial',   # keep partially transferred files
            '-avz',       # archive mode, verbose, compress
            '--relative'  # preserve relative paths
        ]

        if pull:
            # Pull mode: remote -> local
            print(f"Pulling model from {remote_host}...")
            # Ensure local directory exists
            os.makedirs(source_ollama_path, exist_ok=True)
            rsync_cmd.extend([
                f'{remote_host}:{dest_ollama_path}/{model_path}',  # source: remote model
                f'{remote_host}:{dest_ollama_path}/{blobs_path}/',  # source: remote blobs
                source_ollama_path  # destination: local ollama path
            ])
        else:
            # Push mode: local -> remote
            print(f"Pushing model to {remote_host}...")
            rsync_cmd.extend([
                '--rsync-path', f'mkdir -p {dest_ollama_path} && rsync',  # ensure remote directory exists
                model_path,     # source: local model
                f'{blobs_path}/',  # source: local blobs
                f'{remote_host}:{dest_ollama_path}/'  # destination: remote ollama path
            ])

        # Execute rsync
        print(f"Running rsync {'from' if pull else 'to'} {remote_host}...")
        result = subprocess.Popen(rsync_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        for line in result.stdout:
            print(line, end='')
        result.communicate()
        if result.returncode != 0:
            raise subprocess.CalledProcessError(result.returncode, result.args)
        if result.stderr:
            print("rsync output:", result.stderr)
        print(f"Model '{repository}/{model_name}:{model_tag}' successfully synced to {remote_host}:{dest_ollama_path}")

    except subprocess.CalledProcessError as e:
        print(f"Error syncing model: {e}")
        if e.stdout:
            print("stdout:", e.stdout)
        if e.stderr:
            print("stderr:", e.stderr)
        raise
    except Exception as e:
        print(f"Error: {e}")
        raise
    finally:
        # Always return to original directory
        os.chdir(original_dir)

def create_zip(ollama_path, registry, repository, model_name, model_tag, output_zip):
    manifest_path = get_model_manifest_path(ollama_path, registry, repository, model_name, model_tag)
    if not manifest_path.exists():
        raise FileNotFoundError(f"Could not find model manifest in any of the expected locations for {model_name}:{model_tag}")

    manifest = read_manifest(manifest_path)

    with zipfile.ZipFile(output_zip, 'w') as zipf:
        # Add manifest file
        zipf.write(manifest_path, arcname=manifest_path.relative_to(ollama_path))

        # Add blobs
        for layer in manifest['layers']:
            blob_path = get_blob_file_path(ollama_path, layer['digest'])
            zipf.write(blob_path, arcname=blob_path.relative_to(ollama_path))

        # Add config blob
        config_blob_path = get_blob_file_path(ollama_path, manifest['config']['digest'])
        zipf.write(config_blob_path, arcname=config_blob_path.relative_to(ollama_path))

    print(f"Model '{repository}/{model_name}:{model_tag}' exported successfully to '{output_zip}'")
    print(f"You can import it to another Ollama instance with 'tar -xf {output_zip}'")

def compare_models(local_path, remote_host, remote_path):
    """Compare local and remote models, returning models that exist only locally."""
    print("Scanning local models...")
    local_models = list_models(local_path)
    if not local_models:
        print("No local models found.")
        return []

    print(f"\nFound {len(local_models)} local models.")

    print(f"\nScanning remote models on {remote_host}...")
    try:
        # List remote models using ls command instead of Python script
        cmd = f"ssh {remote_host} 'find {remote_path}/models/manifests -mindepth 4 -maxdepth 4 -type d'"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)

        if result.returncode != 0:
            print(f"Error accessing remote host: {result.stderr}")
            return []

        # Parse remote models from directory structure
        remote_models = set()
        for line in result.stdout.splitlines():
            if not line.strip():
                continue
            try:
                # Extract model info from path
                parts = Path(line).parts
                if len(parts) >= 4:
                    registry_idx = parts.index('manifests') + 1
                    if registry_idx + 3 < len(parts):
                        repo = parts[registry_idx + 1]
                        model = parts[registry_idx + 2]
                        tag = parts[registry_idx + 3]
                        if repo == 'library':
                            remote_models.add((model, tag))
                        else:
                            remote_models.add((f"{repo}/{model}", tag))
            except Exception as e:
                print(f"Warning: Error processing remote path {line}: {e}")

        print(f"Found {len(remote_models)} remote models.")

        # Find models that exist only locally
        unique_local = set(local_models) - remote_models
        if unique_local:
            print(f"\nFound {len(unique_local)} models that exist only locally.")
        return sorted(unique_local)

    except Exception as e:
        print(f"Error comparing models: {e}")
        return []

def main():
    # Default paths
    homedir = Path.home()
    default_ollama_path = homedir / ".ollama"

    # Environment variables take precedence over defaults
    ollama_path_default = os.getenv('OLLAMA_PATH', str(default_ollama_path))
    env_defaults = {
        'ollama_path': ollama_path_default,
        'remote_ollama_path': os.getenv('REMOTE_OLLAMA_PATH', ollama_path_default),
        'registry': os.getenv('OLLAMA_REGISTRY', 'registry.ollama.ai'),
        'repository': os.getenv('OLLAMA_REPOSITORY', 'library'),
        'output': os.getenv('OLLAMA_OUTPUT'),
        'remote_host': os.getenv('OLLAMA_REMOTE_HOST'),
        'model_name': os.getenv('OLLAMA_MODEL_NAME'),
        'model_tag': os.getenv('OLLAMA_MODEL_TAG')
    }

    examples = """
### Example Usage

## List models that exist locally but not on remote host

    python export_ollama_model.py --remote-host user@server --list-unique
    python export_ollama_model.py --remote-host user@server --remote-ollama-path /opt/ollama --list-unique

## Sync models between hosts

    # Push a model to remote host
    python export_ollama_model.py --remote-host user@server gemma q6_k
    python export_ollama_model.py --remote-host user@server --remote-ollama-path /opt/ollama mistral latest

    # Pull a model from remote host
    python export_ollama_model.py --remote-host user@server --pull gemma 2b
    python export_ollama_model.py --remote-host user@server --remote-ollama-path /opt/ollama --pull mistral latest

## Export a model to a zip file

    python export_ollama_model.py gemma 2b
    python export_ollama_model.py mistral latest --output mistral_backup.zip
    python export_ollama_model.py technobyte/c4ai-command-r7b-12-2024 q5_k_M

## You may also use environment variables to set defaults

    export OLLAMA_MODEL_NAME=gemma
    export OLLAMA_MODEL_TAG=2b
    export OLLAMA_OUTPUT=gemma_backup.zip
    python export_ollama_model.py  # Will use environment variables

    export OLLAMA_REMOTE_HOST=user@server
    python export_ollama_model.py gemma 2b  # Will sync to remote host
    """

    parser = argparse.ArgumentParser(
        description='Export Ollama model to a zip file or sync to remote host.',
        epilog=examples,
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    # Required arguments (unless provided via environment variables)
    parser.add_argument('model_name', type=str, nargs='?', default=env_defaults['model_name'],
                      help='Name of the model (e.g., gemma or repo/model) [env: OLLAMA_MODEL_NAME]')
    parser.add_argument('model_tag', type=str, nargs='?', default=env_defaults['model_tag'],
                      help='Tag of the model (e.g., 2b) [env: OLLAMA_MODEL_TAG]')

    # Optional arguments
    parser.add_argument('--ollama-path', type=str, default=env_defaults['ollama_path'],
                      help='Path to local .ollama directory [env: OLLAMA_PATH]')
    parser.add_argument('--remote-ollama-path', type=str, default=env_defaults['remote_ollama_path'],
                      help='Path to remote .ollama directory [env: REMOTE_OLLAMA_PATH]')
    parser.add_argument('--registry', type=str, default=env_defaults['registry'],
                      help="The Ollama model registry [env: OLLAMA_REGISTRY]")
    parser.add_argument('--repository', type=str, default=env_defaults['repository'],
                      help="Name of the repository (e.g., jina) [env: OLLAMA_REPOSITORY]")
    parser.add_argument('--output', type=str, default=env_defaults['output'],
                      help='Output zip file name [env: OLLAMA_OUTPUT]')
    parser.add_argument('--remote-host', type=str, default=env_defaults['remote_host'],
                      help='Remote host (e.g., user@remote) [env: OLLAMA_REMOTE_HOST]')
    parser.add_argument('--list-unique', action='store_true',
                      help='List models that exist locally but not on the remote host')
    parser.add_argument('--pull', action='store_true',
                      help='Pull model from remote host instead of pushing')

    args = parser.parse_args()

    # Validate arguments based on mode
    if args.list_unique:
        if not args.remote_host:
            parser.error("--remote-host is required when using --list-unique")
    else:
        # Regular mode requires model name and tag
        if not args.model_name or not args.model_tag:
            parser.error("model_name and model_tag are required either as arguments or environment variables")

        if args.remote_host and args.output:
            parser.error("Please specify either --output or --remote-host, not both")

    # Ensure local ollama path exists (unless pulling)
    ollama_path = Path(args.ollama_path)
    if not args.pull and not ollama_path.exists():
        parser.error(f"Local Ollama path does not exist: {ollama_path}")

    if args.list_unique:
        # List models that exist locally but not on remote
        unique_models = compare_models(args.ollama_path, args.remote_host, args.remote_ollama_path)
        if unique_models:
            print("\nModels that exist locally but not on remote host:")
            for name, tag in unique_models:
                print(f"  {name}:{tag}")
        else:
            print("\nNo unique local models found.")
    elif args.remote_host:
        rsync_model(
            ollama_path,
            args.remote_ollama_path,
            args.registry,
            args.repository,
            args.model_name,
            args.model_tag,
            args.remote_host,
            pull=args.pull
        )
    else:
        output_zip = args.output or f"{args.model_name}_{args.model_tag}_export.zip"
        create_zip(ollama_path, args.registry, args.repository, args.model_name, args.model_tag, output_zip)

if __name__ == "__main__":
    main()
