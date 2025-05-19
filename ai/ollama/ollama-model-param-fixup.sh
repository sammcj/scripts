#!/bin/bash

# Script to fix / replace parameters in Ollama models
# Default behaviour is dry-run mode

# Default values
OUTPUT_DIR="/mnt/llm/models/modelfix"
DRY_RUN=true
DOCKER_CONTAINER="ollama"
MODEL_PATTERN="qwen3"
PARAMS_TO_REMOVE=("presest_penalty" "presense_penalty")
declare -A PARAMS_TO_ADD
PARAMS_TO_ADD["presence_penalty"]="1.5"

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Fix parameter issues in Ollama models"
    echo
    echo "Options:"
    echo "  -d, --directory DIR      Output directory for modelfiles (default: $OUTPUT_DIR)"
    echo "  -c, --container NAME     Docker container name (default: $DOCKER_CONTAINER)"
    echo "  -p, --pattern PATTERN    Model name pattern to match (default: \"$MODEL_PATTERN\")"
    echo "  -r, --remove PARAM       Parameter to remove (can be specified multiple times)"
    echo "                           (default: ${PARAMS_TO_REMOVE[*]})"
    echo "  -a, --add \"PARAM VALUE\"  Parameter to add with its value (can be specified multiple times)"
    echo "                           (default: presence_penalty 1.5)"
    echo "  -e, --execute            Execute model recreation (default: dry run)"
    echo "  -h, --help               Display this help message and exit"
    echo
    echo "Examples:"
    echo "  $0 --pattern \"qwen3\" --remove \"presense_penalty\" --add \"presence_penalty 1.5\""
    echo "  $0 --pattern \"llama\" --remove \"frequency_penalty\" --add \"freq_penalty 1.0\" --execute"
    echo
}

# Parse arguments
declare -A custom_params_to_add
custom_params_specified=false
custom_params_to_remove=()
custom_remove_specified=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--directory)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -c|--container)
            DOCKER_CONTAINER="$2"
            shift 2
            ;;
        -p|--pattern)
            MODEL_PATTERN="$2"
            shift 2
            ;;
        -r|--remove)
            custom_params_to_remove+=("$2")
            custom_remove_specified=true
            shift 2
            ;;
        -a|--add)
            # Split param and value
            param_string="$2"
            param_name="${param_string%% *}"
            param_value="${param_string#* }"

            if [ "$param_name" == "$param_value" ]; then
                echo "Error: The --add option requires both a parameter name and value separated by a space."
                echo "Example: --add \"presence_penalty 1.5\""
                exit 1
            fi

            custom_params_to_add["$param_name"]="$param_value"
            custom_params_specified=true
            shift 2
            ;;
        -e|--execute)
            DRY_RUN=false
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Replace defaults with custom values if specified
if [ "$custom_params_specified" = true ]; then
    # Clear default params and use custom ones
    unset PARAMS_TO_ADD
    declare -A PARAMS_TO_ADD
    for key in "${!custom_params_to_add[@]}"; do
        PARAMS_TO_ADD["$key"]="${custom_params_to_add[$key]}"
    done
fi

if [ "$custom_remove_specified" = true ]; then
    # Clear default remove params and use custom ones
    PARAMS_TO_REMOVE=("${custom_params_to_remove[@]}")
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"
rm -rf "$OUTPUT_DIR"/*

echo "Starting Ollama model parameter fix script"
echo "Output directory: $OUTPUT_DIR"
echo "Dry run mode: $DRY_RUN"
echo "Docker container: $DOCKER_CONTAINER"
echo "Model pattern: $MODEL_PATTERN"
echo "Parameters to remove: ${PARAMS_TO_REMOVE[*]}"
echo "Parameters to add:"
for key in "${!PARAMS_TO_ADD[@]}"; do
    echo "  - $key: ${PARAMS_TO_ADD[$key]}"
done
echo

# Get list of matching models
echo "Fetching list of models matching pattern: $MODEL_PATTERN"
MODELS=$(docker exec $DOCKER_CONTAINER ollama list | grep "$MODEL_PATTERN" | awk '{print $1}')

if [ -z "$MODELS" ]; then
    echo "No models matching pattern \"$MODEL_PATTERN\" found."
    exit 0
fi

# Initialize arrays to track models
MODELS_TO_FIX=()
MODELS_ALREADY_CORRECT=()

# Build grep pattern for parameters to remove
REMOVE_PATTERN=""
for param in "${PARAMS_TO_REMOVE[@]}"; do
    if [ -n "$REMOVE_PATTERN" ]; then
        REMOVE_PATTERN="${REMOVE_PATTERN}|${param}"
    else
        REMOVE_PATTERN="${param}"
    fi
done

# First pass - check all models to identify which ones need fixing
echo "Checking models for parameter issues..."
for MODEL in $MODELS; do
    # Generate a safe filename by replacing : with . and / with _
    SAFE_FILENAME=$(echo "$MODEL" | tr ':' '.' | tr '/' '_')
    FILEPATH="$OUTPUT_DIR/${SAFE_FILENAME}.modelfile"

    # Extract modelfile quietly
    docker exec $DOCKER_CONTAINER ollama show --modelfile "$MODEL" > "$FILEPATH" 2>/dev/null
    dos2unix "$FILEPATH" 2>/dev/null

    # Check for parameters to remove
    NEEDS_FIX=false
    if [ -n "$REMOVE_PATTERN" ] && grep -E "$REMOVE_PATTERN" "$FILEPATH" >/dev/null; then
        NEEDS_FIX=true
    fi

    # Check if parameters to add are already present
    for param_name in "${!PARAMS_TO_ADD[@]}"; do
        if ! grep -q "$param_name" "$FILEPATH"; then
            NEEDS_FIX=true
        fi
    done

    if [ "$NEEDS_FIX" = true ]; then
        MODELS_TO_FIX+=("$MODEL")
    else
        MODELS_ALREADY_CORRECT+=("$MODEL")
    fi
done

# Display summary of models found
echo "Found $(echo "$MODELS" | wc -w) models matching pattern \"$MODEL_PATTERN\":"
echo "  - ${#MODELS_TO_FIX[@]} models with parameter issues to fix"
echo "  - ${#MODELS_ALREADY_CORRECT[@]} models already correct"
echo

# If no models need fixing, exit early
if [ ${#MODELS_TO_FIX[@]} -eq 0 ]; then
    echo "No models need parameter fixes. Exiting."
    exit 0
fi

# Process only models that need fixing
echo "Processing models with parameter issues:"
for MODEL in "${MODELS_TO_FIX[@]}"; do
    echo "Processing model: $MODEL"

    # Generate a safe filename by replacing : with . and / with _
    SAFE_FILENAME=$(echo "$MODEL" | tr ':' '.' | tr '/' '_')
    FILEPATH="$OUTPUT_DIR/${SAFE_FILENAME}.modelfile"

    echo "  Extracting modelfile to $FILEPATH"
    docker exec $DOCKER_CONTAINER ollama show --modelfile "$MODEL" > "$FILEPATH"

    echo "  Running dos2unix on $FILEPATH"
    dos2unix "$FILEPATH" 2>/dev/null

    # Fix incorrect parameter names
    echo "  Fixing parameters in modelfile"

    # Remove parameters
    for param in "${PARAMS_TO_REMOVE[@]}"; do
        if grep -q "$param" "$FILEPATH"; then
            echo "  Removing parameter: $param"
            sed -i "/$param/d" "$FILEPATH"
        fi
    done

    # Add parameters if they don't exist
    for param_name in "${!PARAMS_TO_ADD[@]}"; do
        param_value="${PARAMS_TO_ADD[$param_name]}"
        if ! grep -q "$param_name" "$FILEPATH"; then
            echo "  Adding parameter: $param_name $param_value"
            echo "PARAMETER $param_name $param_value" >> "$FILEPATH"
        else
            echo "  Parameter $param_name already exists"
        fi
    done

    # Use the same file path in the container since /mnt/llm/models is shared
    # No need to copy the file to the container
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY RUN] Would execute: docker exec $DOCKER_CONTAINER ollama create $MODEL -f $FILEPATH"
    else
        echo "  Recreating model with command: docker exec $DOCKER_CONTAINER ollama create $MODEL -f $FILEPATH"
        docker exec $DOCKER_CONTAINER ollama create "$MODEL" -f "$FILEPATH"

        if [ $? -eq 0 ]; then
            echo "  Successfully recreated model $MODEL"
        else
            echo "  Failed to recreate model $MODEL"
        fi
    fi

    echo "  Done processing $MODEL"
    echo
done

echo "Script completed"
echo "Models with parameter issues that were processed:"
for MODEL in "${MODELS_TO_FIX[@]}"; do
    echo "  - $MODEL"
done

if [ "$DRY_RUN" = true ]; then
    echo "This was a dry run. To actually recreate the models, run with the --execute flag."
fi
