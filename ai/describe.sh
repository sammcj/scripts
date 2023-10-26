#!/bin/bash

# This script is used to describe an image using the LLM model
# It can be integrated with the Finder's "Open With" menu
# Example models: https://huggingface.co/mys/ggml_llava-v1.5-7b/tree/main

# Path to AI llama/llava tool binary
# LLAVA_BIN="${HOME}/git/llama.cpp/build/bin/llava"
LLAVA_BIN="/usr/local/bin/llava"

# Directory containing the LLM models
MODELS_DIR="/Volumes/USB-SATA/LLM/models/llava"

# GRAMMARS_DIR="/Users/${USER}/git/llama.cpp/grammars"
# GRAMMAR="json.gbnf"

# Specific models to be used
MODEL="ggml-model-q4_k.gguf"
MMPROJ="mmproj-model-f16.gguf"

# Get the input image path from the first argument
IMAGE="$1"

# Set tunable variables
TOKENS=512
THREADS=8
MTEMP=0.1
MPROMPT="Describe the image in as much detail as possible."
# MPROMPT="Describe the image in as much detail as possible, I will use this description in the text2image tool. Mention a style if possible."
MCONTEXT=512
GPULAYERS=1

# Run llama/llava tool to describe the image
OUTPUT=$(${LLAVA_BIN} -m ${MODELS_DIR}/${MODEL} --mmproj ${MODELS_DIR}/${MMPROJ} --threads ${THREADS} --temp ${MTEMP} --prompt "${MPROMPT}" --image "${IMAGE}" --n-gpu-layers ${GPULAYERS} --ctx-size ${MCONTEXT} --n-predict ${TOKENS})

# --grammar-file "${GRAMMARS_DIR}"/${GRAMMAR} --color

# Copy output to clipboard
echo "$OUTPUT" | pbcopy

# Make a sound when capture is done
say "Done."
