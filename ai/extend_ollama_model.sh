#!/usr/bin/env bash

# Script to extend Ollama models with custom context sizes
# Usage: extend_ollama_models.sh [context_size] [model_name]

set -eo pipefail

# If set to "true", the script will create additional models with context sizes 8192, 16384 and 65536
CREATE_ADDITIONAL_CTX_MODELS=${CREATE_ADDITIONAL_CTX_MODELS:-"false"}

# Default context size
DEFAULT_CTX_SIZE=32768
TEMPERATURE=0.1
TOP_P=0.85

# Helper function to show usage
usage() {
  echo "Usage: $(basename "$0") [context_size] [model_name]"
  echo "  context_size: (optional) Size of the context window (default: ${DEFAULT_CTX_SIZE})"
  echo "  model_name: (optional) Specific model to extend (format: name:variant)"
  echo ""
  echo "Examples:"
  echo "  $(basename "$0")                                      # Extends all models with default context size"
  echo "  $(basename "$0") 32768                                # Extends all models with specified context size"
  echo "  $(basename "$0") 32768 'qwen2.5:32b-instruct-q6_K'    # Extends specific model with specified context size"
  exit 1
}

# Validate arguments
ctx_size=${1:-$DEFAULT_CTX_SIZE}
model_name=${2:-}

# Validate context size is a number
if ! [[ $ctx_size =~ ^[0-9]+$ ]]; then
  echo "Error: context size must be a positive integer"
  usage
fi

# Check if ollama container is running
if ! docker ps --format "{{.Names}}" | grep -q "^ollama$"; then
  echo "Error: ollama container is not running"
  exit 1
fi

# Function to extend a single model
extend_single_model() {
  local model_name=$1     # e.g. qwen2.5:32b-instruct-q6_K
  local ctx_size=$2       # e.g. 32768
  local base_name variant # e.g. qwen2.5, 32b-instruct-q6_K

  base_name=$(echo "$model_name" | cut -d':' -f1)
  variant=$(echo "$model_name" | cut -d':' -f2)

  if echo "$variant" | grep -q "${ctx_size}" || echo "base_name" | grep -q "${ctx_size}" || echo "$model_name" | grep -q "${ctx_size}"; then
    echo "Model $model_name already has context size $ctx_size"
    return 0
  fi

  echo "Extending model: $model_name with context size: $ctx_size"

  # If the model is 3-8b in the name, set $num_batch to 1024
  if echo "$model_name" | grep -q "3b\|4b\|7b\|8b"; then
    num_batch=1024
  else
    num_batch=512
  fi

  # Create a safe filename by replacing / with _
  local safe_filename="Modelfile-${model_name//\//_}"

  # Create Modelfile inside the container
  docker exec ollama bash -c "cat > \"$safe_filename\" << EOF
FROM $model_name

PARAMETER num_ctx $ctx_size
PARAMETER temperature $TEMPERATURE
PARAMETER top_p $TOP_P
PARAMETER num_batch $num_batch
EOF"

  # Create extended model inside the container
  docker exec ollama ollama create "${base_name}-${ctx_size}:${variant}" -f "$safe_filename"
  docker exec ollama rm "$safe_filename"
  echo "Created extended model: ${base_name}-${ctx_size}:${variant}"
}

# If a specific model is provided, validate and extend just that model
if [ -n "$model_name" ]; then
  if ! [[ "$model_name" =~ ^[a-zA-Z0-9._-]+:[a-zA-Z0-9._-]+$ ]]; then
    echo "Error: Invalid model name format. Expected format: name:variant"
    usage
  fi
  extend_single_model "$model_name" "$ctx_size"
  exit 0
fi

# If no specific model provided, process all models
echo "Extending all models with context size: $ctx_size"
docker exec ollama ollama list | tail -n +2 | while read -r line; do
  model_name=$(echo "$line" | awk '{print $1}')
  extend_single_model "$model_name" "$ctx_size"
done

if [ "$CREATE_ADDITIONAL_CTX_MODELS" = "true" ]; then
  echo "Creating additional models with context sizes 8192, 16384 and 65536"
  DEFAULT_CTX_SIZE=8192 "$0"
  DEFAULT_CTX_SIZE=16384 "$0"
  DEFAULT_CTX_SIZE=65536 "$0"
fi
