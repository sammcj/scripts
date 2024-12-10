#!/usr/bin/env bash

# This script will build Ollama and it's macOS App from the Ollama git repo along with the latest llama.cpp.

set -e # exit on error
set -x # debug output

macOSSDK=$(xcrun --show-sdk-path)
export macOSSDK

# OLLAMA_GIT_REPO="${OLLAMA_GIT_REPO:-https://github.com/ollama/ollama.git}"
# OLLAMA_GIT_DIR="${OLLAMA_GIT_DIR:-$HOME/git/ollama}"
# OLLAMA_GIT_BRANCH="${OLLAMA_GIT_BRANCH:-main}"

OLLAMA_GIT_REPO="${OLLAMA_GIT_REPO:-https://github.com/sammcj/ollama.git}"
OLLAMA_GIT_DIR="${OLLAMA_GIT_DIR:-$HOME/git/ollama-fork}"
OLLAMA_GIT_BRANCH="${OLLAMA_GIT_BRANCH:-fix/memory_estimates}"

PATCH_OLLAMA=${PATCH_OLLAMA:-"true"}
PATCH_OLLAMA=$(echo "$PATCH_OLLAMA" | tr '[:upper:]' '[:lower:]')
DEFAULT_BATCH_SIZE=${DEFAULT_BATCH_SIZE:-512}

export OLLAMA_DEBUG=0
export GIN_MODE=release
export ACCELERATE_FRAMEWORK="${macOSSDK}/System/Library/Frameworks/Accelerate.framework"
export FOUNDATION_FRAMEWORK="${macOSSDK}/System/Library/Frameworks/Foundation.framework"
export VECLIB_FRAMEWORK="${macOSSDK}/System/Library/Frameworks/vecLib.framework"
export CLBLAST_FRAMEWORK="/opt/homebrew/Cellar/clblast"
export CLBlast_DIR="/opt/homebrew/lib/cmake/CLBlast"
export BLAS_INCLUDE_DIRS="${CLBLAST_FRAMEWORK},${VECLIB_FRAMEWORK},${ACCELERATE_FRAMEWORK},${FOUNDATION_FRAMEWORK},/opt/homebrew/Cellar/openblas"
export BUILD_LLAMA_CPP_FIRST=${BUILD_LLAMA_CPP_FIRST:-true}
export OLLAMA_MAX_LOADED_MODELS=4
export OLLAMA_KEEP_ALIVE='8h'
export OLLAMA_ORIGINS='http://localhost:*,https://localhost:*,app://obsidian.md*,app://*'
export OLLAMA_KV_CACHE_TYPE=q8_0
export OLLAMA_FLASH_ATTENTION=1
export CGO_LDFLAGS="-Wl,-no_warn_duplicate_libraries"
export OLLAMA_CUSTOM_CPU_DEFS="-DGGML_NATIVE=on -DGGML_F16C=on -DGGML_FMA=on -DGGML_SCHED_MAX_COPIES=6"

# a function that takes input (error output from another command), and stores it in a variable for printing later
function store_error() {
  errors+=("""  - Stored error from line $LINENO: $1""")
}

trap 'store_error "Error on line $LINENO, last command: $BASH_COMMAND"' ERR

# if openblas isn't installed, run brew install openblas
if [ ! -d "/opt/homebrew/Cellar/openblas" ]; then
  echo "openblas not found, installing..."
  brew install openblas
fi

function patch_ollama() {
  if [ "$PATCH_OLLAMA" != true ]; then
    echo "skipping patching of ollama build config"
    return
  fi

  echo "patching ollama with Sams defaults"

  # apply patches
  patch -p1 <~/git/sammcj/scripts/ollama/ollama_patches.diff || exit 1

  gsed -i 's/FlashAttn: false,/FlashAttn: true,/g' "$OLLAMA_GIT_DIR"/api/types.go
  gsed -i 's/NumBatch:  512,/NumBatch:  '"$DEFAULT_BATCH_SIZE"',/g' "$OLLAMA_GIT_DIR"/api/types.go
  gsed -i 's/Temperature:      0.8,/Temperature:      0.4,/g' "$OLLAMA_GIT_DIR"/api/types.go
  gsed -i 's/TopP:             0.9,/TopP:             0.85,/g' "$OLLAMA_GIT_DIR"/api/types.go
  gsed -i 's/NumCtx:    2048,/NumCtx:    8192,/g' "$OLLAMA_GIT_DIR"/api/types.go

  gsed -i '2i export BLAS_INCLUDE_DIRS='"$BLAS_INCLUDE_DIRS"'' "$OLLAMA_GIT_DIR"/scripts/build_darwin.sh

  # set ldflags to disable warnings spamming the output
  gsed -i '2i export LDFLAGS="-w"' "$OLLAMA_GIT_DIR"/scripts/build_darwin.sh
}

function build_cli() {
  echo "building ollama cli"
  cd "$OLLAMA_GIT_DIR" || exit

  mkdir -p dist
  # OLLAMA_CUSTOM_CPU_DEFS=$OLLAMA_CUSTOM_CPU_DEFS VERSION=$VERSION BLAS_INCLUDE_DIRS=$BLAS_INCLUDE_DIRS go generate ./... || exit 1
  # OLLAMA_CUSTOM_CPU_DEFS=$OLLAMA_CUSTOM_CPU_DEFS VERSION=$VERSION BLAS_INCLUDE_DIRS=$BLAS_INCLUDE_DIRS go build -o dist/ollama . || exit 1
  OLLAMA_CUSTOM_CPU_DEFS="$OLLAMA_CUSTOM_CPU_DEFS" VERSION="$VERSION" BLAS_INCLUDE_DIRS="$BLAS_INCLUDE_DIRS" make -j "$(expr "$(nproc)" / 2)" || exit 1
  cp -f ollama dist/ollama
}

function build_app() {
  echo "building ollama app"
  cd "$OLLAMA_GIT_DIR"/macapp || exit

  set -e

  npm i
  npx electron-forge make --arch arm64

  codesign --force --deep --sign - out/Ollama-darwin-arm64/Ollama.app

  # check if Ollama is running, if it is set WAS_RUNNING to true
  if pgrep -x "Ollama" >/dev/null; then
    export OLLAMA_WAS_RUNNING=true
  fi

  # stop the app if it's running
  pkill Ollama || true

  rm -rf /Applications/Ollama.app
  mv out/Ollama-darwin-arm64/Ollama.app /Applications/Ollama.app
  codesign --force --deep --sign - /Applications/Ollama.app

  set +e
}

function update_fw_rules() {
  if [ ! -f "/usr/libexec/ApplicationFirewall/socketfilterfw" ]; then
    echo "socketfilterfw not found, skipping"
    return
  fi

  # Tell the fw to accept the modified app
  /usr/libexec/ApplicationFirewall/socketfilterfw --add /Applications/Ollama.app
  /usr/libexec/ApplicationFirewall/socketfilterfw --add /Applications/Ollama.app/Contents/MacOS/Ollama
  # And accept if the app exists already but has been modified
  /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /Applications/Ollama.app
  /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /Applications/Ollama.app/Contents/MacOS/Ollama
  sleep 1
}

function update_git() {
  if [ ! -d "$OLLAMA_GIT_DIR" ]; then
    echo "cloning ollama git repo"
    # one directory up from the git repo
    BASE_DIR=$(dirname "$OLLAMA_GIT_DIR")
    mkdir -p "$BASE_DIR"
    cd "$BASE_DIR" || exit

    git clone -j6 "$OLLAMA_GIT_REPO" --depth=1
    git checkout "$OLLAMA_GIT_BRANCH"
  fi

  echo "updating ollama git repo"
  cd "$OLLAMA_GIT_DIR" || exit
  rm -rf llm/llama.cpp dist ollama llm/build macapp/out

  set -e
  git reset --hard HEAD
  git fetch --tags --force
  git pull
  git rebase --abort
  # git checkout feature/kv-quant
  cd "$OLLAMA_GIT_DIR" || exit
  set +e
}

function set_version() {
  cd "$OLLAMA_GIT_DIR" || exit
  VERSION=$(git describe --tags --always)
  export VERSION
  echo "Ollama version (from git tag): $VERSION"
}

function run_app() {
  cd "$OLLAMA_GIT_DIR" || exit

  if [ -z "$(launchctl getenv OLLAMA_ORIGINS)" ]; then
    echo "setting OLLAMA_ORIGINS"
    launchctl setenv OLLAMA_ORIGINS "$OLLAMA_ORIGINS"
  fi

  # if [ -z "$(launchctl getenv OLLAMA_NUM_PARALLEL)" ]; then
  #   echo "setting OLLAMA_NUM_PARALLEL"
  #   launchctl setenv OLLAMA_NUM_PARALLEL "$OLLAMA_NUM_PARALLEL"
  # fi

  if [ -z "$(launchctl getenv OLLAMA_KV_CACHE_TYPE)" ]; then
    echo "setting OLLAMA_KV_CACHE_TYPE"
    launchctl setenv OLLAMA_KV_CACHE_TYPE "$OLLAMA_KV_CACHE_TYPE"
  fi

  if [ -z "$(launchctl getenv OLLAMA_MAX_LOADED_MODELS)" ]; then
    echo "setting OLLAMA_MAX_LOADED_MODELS"
    launchctl setenv OLLAMA_MAX_LOADED_MODELS "$OLLAMA_MAX_LOADED_MODELS"
  fi

  if [ -z "$(launchctl getenv OLLAMA_FLASH_ATTENTION)" ]; then
    echo "setting OLLAMA_FLASH_ATTENTION"
    launchctl setenv OLLAMA_FLASH_ATTENTION "$OLLAMA_FLASH_ATTENTION"
  fi

  if [ -z "$(launchctl getenv OLLAMA_KEEP_ALIVE)" ]; then
    echo "setting OLLAMA_KEEP_ALIVE"
    launchctl setenv OLLAMA_KEEP_ALIVE "$OLLAMA_KEEP_ALIVE"
  fi

  if [ "$OLLAMA_WAS_RUNNING" = true ]; then
    echo "Ollama was running, restarting..."
    open "/Applications/Ollama.app"
  fi
}

# cleanup first
rm -rf /Users/samm/git/ollama/.git/modules/llama.cpp/rebase-apply || true
# rm -rf /Users/samm/git/ollama-fork/.git/modules/llama.cpp/rebase-apply || true

update_git || store_error "Failed to update git"
set_version || store_error "Failed to set version"
patch_ollama || store_error "Failed to patch ollama"
build_cli || store_error "Failed to build ollama cli"
build_app || store_error "Failed to build ollama app"
# update_fw_rules || store_error "Failed to update firewall rules"
run_app || store_error "Failed to run app"

# unset the error trap
trap - ERR

# print any errors that were stored
if [ ${#errors[@]} -gt 0 ]; then
  # set text to red
  tput setaf 1
  echo "---"
  echo "Stored Errors:"
  for error in "${errors[@]}"; do
    echo "$error"
  done
  echo "---"
  tput sgr0
  exit 1
fi
