#!/usr/bin/env bash

set -ex

OLLAMA_GIT_DIR="$HOME/git/ollama"

export OLLAMA_DEBUG=0
export GIN_MODE=release
export BLAS_INCLUDE_DIRS=/opt/homebrew/Cellar/clblast/1.6.2/,/opt/homebrew/Cellar/openblas/0.3.27/include,/opt/homebrew/Cellar/gsl/2.7.1/include/gsl,/opt/homebrew/Cellar/clblast/1.6.2/include

function patch_ollama() {
  echo "patching ollama"

  if [ ! -f "$OLLAMA_GIT_DIR/llm/generate/gen_darwin.sh" ]; then
    cp "$OLLAMA_GIT_DIR"/llm/generate/gen_darwin.sh "$OLLAMA_GIT_DIR"/llm/generate/gen_darwin.sh.bak
  fi

  if [ ! -f "$OLLAMA_GIT_DIR/scripts/build_darwin.sh" ]; then
    cp "$OLLAMA_GIT_DIR"/scripts/build_darwin.sh "$OLLAMA_GIT_DIR"/scripts/build_darwin.sh.bak
  fi

  sed -i '' "s/-DLLAMA_ACCELERATE=on/-DLLAMA_ACCELERATE=on -DLLAMA_SCHED_MAX_COPIES=6 -DLLAMA_METAL_MACOSX_VERSION_MIN=14.1 -DLLAMA_NATIVE=on -DLLAMA_CLBLAST=on -DLLAMA_F16C=on -DLLAMA_CURL=on -DCLBlast_DIR=\/opt\/homebrew\/Cellar\/clblast\/1.6.2\/ -Wno-dev/g" "$OLLAMA_GIT_DIR"/llm/generate/gen_darwin.sh
  #   -DLLAMA_QKK_64=on -DLLAMA_BLAS_VENDOR=Apple -DLLAMA_VULKAN=on

  # add export BLAS_INCLUDE_DIRS=$BLAS_INCLUDE_DIRS to the second line of the gen_darwin.sh and scripts/build_darwin.sh files
  gsed -i '2i export BLAS_INCLUDE_DIRS='$BLAS_INCLUDE_DIRS'' "$OLLAMA_GIT_DIR"/llm/generate/gen_darwin.sh
  gsed -i '2i export BLAS_INCLUDE_DIRS='$BLAS_INCLUDE_DIRS'' "$OLLAMA_GIT_DIR"/scripts/build_darwin.sh
}

function build_cli() {
  echo "building ollama cli"
  cd "$OLLAMA_GIT_DIR" || exit

  mkdir -p dist
  BLAS_INCLUDE_DIRS=$BLAS_INCLUDE_DIRS go generate ./...
  BLAS_INCLUDE_DIRS=$BLAS_INCLUDE_DIRS go build -o dist/ollama .
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

  # Tell littlesnitch to accept the modified app
  /usr/libexec/ApplicationFirewall/socketfilterfw --add /Applications/Ollama.app
  /usr/libexec/ApplicationFirewall/socketfilterfw --add /Applications/Ollama.app/Contents/MacOS/Ollama
  # And accept if the app exists already but has been modified
  /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /Applications/Ollama.app
  /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /Applications/Ollama.app/Contents/MacOS/Ollama
  sleep 1

}

function update_git() {
  echo "updating ollama git repo"
  cd "$OLLAMA_GIT_DIR" || exit
  rm -rf llm/llama.cpp dist ollama llm/build macapp/out
  git reset --hard HEAD
  git pull
  git submodule init
  git submodule update
}

function run_app() {
  cd "$OLLAMA_GIT_DIR" || exit
  open "/Applications/Ollama.app"
  # sleep 1 && ollama list
  # ./dist/ollama serve
}

update_git
patch_ollama
build_cli
build_app
run_app
