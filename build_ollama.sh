#!/usr/bin/env bash

# This script will build Ollama and it's macOS App from the Ollama git repo along with the latest llama.cpp.

set -e # exit on error
# set -x # debug output

OLLAMA_GIT_DIR="$HOME/git/ollama"
PATCH_OLLAMA=${PATCH_OLLAMA:-"true"}
# normalise PATCH_OLLAMA to a boolean
PATCH_OLLAMA=$(echo "$PATCH_OLLAMA" | tr '[:upper:]' '[:lower:]')

export OLLAMA_DEBUG=0
export GIN_MODE=release
export BLAS_INCLUDE_DIRS=/opt/homebrew/Cellar/clblast/1.6.2/,/opt/homebrew/Cellar/openblas/0.3.27/include,/opt/homebrew/Cellar/gsl/2.7.1/include/gsl,/opt/homebrew/Cellar/clblast/1.6.2/include

# a function that takes input (error output from another command), and stores it in a variable for printing later
function store_error() {
  errors+=("""  - Stored error from line $LINENO: $1""")
}

trap 'store_error "Error on line $LINENO"' ERR

function patch_llama() {
  # custom patches for llama.cpp
  # Take a PR to llama.cpp, e.g. https://github.com/ggerganov/llama.cpp/pull/6707/files, get the fork and branch being requested to merge and apply it to the local llama.cpp (llm/llama.cpp)
  PRs=(
    "https://github.com/ggerganov/llama.cpp/pull/6707" # Add CodeQwen support
  )

  cd "$OLLAMA_GIT_DIR/llm/llama.cpp" || exit

  for PR in "${PRs[@]}"; do
    PATCH=$(curl -sSL "$PR.diff")
    tput setaf 7
    echo "------------------------------"
    echo "Applying patch from $PR:"
    echo "$PATCH"
    echo "---"
    echo "Diff:"
    git diff <<<"$PATCH"
    echo "------------------------------"
    tput sgr0
    git apply --check <<<"$PATCH"
    if [ $? -eq 0 ]; then
      git apply <<<"$PATCH"
    else
      store_error "Patch failed to apply cleanly, skipping..."
    fi
  done
}

function patch_ollama() {
  if [ "$PATCH_OLLAMA" != true ]; then
    echo "skipping patching of ollama build config"
    return
  fi

  echo "---"
  echo "TEMPORARY patch of IQ3_XS etc..."
  git remote add mann1x https://github.com/mann1x/ollama.git || true
  git fetch mann1x
  # merge non-interactively
  git merge upstream/mannix-gguf --no-edit
  echo "patched main with https://github.com/mann1x/ollama.git / mannix-gguf"
  echo "---"

  echo "patching ollama with Sams tweaks"

  if [ ! -f "$OLLAMA_GIT_DIR/llm/generate/gen_darwin.sh" ]; then
    cp "$OLLAMA_GIT_DIR"/llm/generate/gen_darwin.sh "$OLLAMA_GIT_DIR"/llm/generate/gen_darwin.sh.bak
  fi

  if [ ! -f "$OLLAMA_GIT_DIR/scripts/build_darwin.sh" ]; then
    cp "$OLLAMA_GIT_DIR"/scripts/build_darwin.sh "$OLLAMA_GIT_DIR"/scripts/build_darwin.sh.bak
  fi

  echo "This is a gross hack as Ollama's build scripts don't seem to honour CMAKE variables properly"
  sed -i '' "s/-DLLAMA_ACCELERATE=on/-DLLAMA_ALL_WARNINGS_3RD_PARTY=off -DLLAMA_ALL_WARNINGS=off -DLLAMA_ACCELERATE=on -DLLAMA_SCHED_MAX_COPIES=6 -DLLAMA_METAL_MACOSX_VERSION_MIN=14.1 -DLLAMA_NATIVE=on -DLLAMA_CLBLAST=on -DLLAMA_F16C=on -DLLAMA_CURL=on -DCLBlast_DIR=\/opt\/homebrew\/Cellar\/clblast\/1.6.2\/ -Wno-dev/g" "$OLLAMA_GIT_DIR"/llm/generate/gen_darwin.sh
  #   -DLLAMA_QKK_64=on -DLLAMA_BLAS_VENDOR=Apple -DLLAMA_VULKAN=on

  # add export BLAS_INCLUDE_DIRS=$BLAS_INCLUDE_DIRS to the second line of the gen_darwin.sh and scripts/build_darwin.sh files
  gsed -i '2i export BLAS_INCLUDE_DIRS='$BLAS_INCLUDE_DIRS'' "$OLLAMA_GIT_DIR"/llm/generate/gen_darwin.sh
  gsed -i '2i export BLAS_INCLUDE_DIRS='$BLAS_INCLUDE_DIRS'' "$OLLAMA_GIT_DIR"/scripts/build_darwin.sh

  # set ldflags to disable warnings spamming the output
  gsed -i '2i export LDFLAGS="-w"' "$OLLAMA_GIT_DIR"/llm/generate/gen_darwin.sh
  gsed -i '2i export LDFLAGS="-w"' "$OLLAMA_GIT_DIR"/scripts/build_darwin.sh

}

function build_cli() {
  echo "building ollama cli"
  cd "$OLLAMA_GIT_DIR" || exit

  mkdir -p dist
  VERSION=$VERSION BLAS_INCLUDE_DIRS=$BLAS_INCLUDE_DIRS go generate ./...
  VERSION=$VERSION BLAS_INCLUDE_DIRS=$BLAS_INCLUDE_DIRS go build -o dist/ollama .
  # go run build.go -f
}

function build_app() {
  echo "building ollama app"
  cd "$OLLAMA_GIT_DIR"/macapp || exit

  npm i
  npx electron-forge make --arch arm64

  codesign --force --deep --sign - out/Ollama-darwin-arm64/Ollama.app

  # stop the app if it's running
  pkill Ollama || true

  rm -rf /Applications/Ollama.app
  mv out/Ollama-darwin-arm64/Ollama.app /Applications/Ollama.app
  codesign --force --deep --sign - /Applications/Ollama.app
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
    cd "$BASE_DIR" || exit
    git clone https://github.com/ollama/ollama.git --depth=1
  fi

  echo "updating ollama git repo"
  cd "$OLLAMA_GIT_DIR" || exit
  rm -rf llm/llama.cpp dist ollama llm/build macapp/out
  git reset --hard HEAD

  # force pull any tags
  git fetch --tags --force
  git pull
  git submodule init
  git submodule update
}

function set_version() {
  cd "$OLLAMA_GIT_DIR" || exit
  VERSION=$(git describe --tags --always)
  export VERSION
  echo "Ollama version (from git tag): $VERSION"

  # replace the version in the app's version/version.go (defaults to var Version string = "0.0.0")
  sed -i '' "s/var Version string = \"0.0.0\"/var Version string = \"$VERSION\"/g" "$OLLAMA_GIT_DIR"/version/version.go

  # replace the version in the app's package.json
  sed -i '' "s/\"version\": \"0.0.0\"/\"version\": \"$VERSION\"/g" "$OLLAMA_GIT_DIR"/macapp/package.json
}

function run_app() {
  cd "$OLLAMA_GIT_DIR" || exit
  launchctl setenv OLLAMA_ORIGINS 'http://localhost:*,https://localhost:*,app://obsidian.md*,app://*'
  open "/Applications/Ollama.app"
  # sleep 1 && ollama list
  # ./dist/ollama serve
}

update_git || store_error "Failed to update git"
set_version || store_error "Failed to set version"
patch_ollama || store_error "Failed to patch ollama"
patch_llama || store_error "Failed to patch llama"
build_cli || store_error "Failed to build ollama cli"
build_app || store_error "Failed to build ollama app"
update_fw_rules || store_error "Failed to update firewall rules"
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
