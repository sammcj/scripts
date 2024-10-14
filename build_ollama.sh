#!/usr/bin/env bash

# This script will build Ollama and it's macOS App from the Ollama git repo along with the latest llama.cpp.

set -e # exit on error
set -x # debug output

# OLLAMA_GIT_DIR="${HOME}/git/ollama"
OLLAMA_GIT_DIR="${HOME}/git/ollama-fork"
LLAMA_GIT_DIR="${HOME}/git/llama.cpp"
PATCH_OLLAMA=${PATCH_OLLAMA:-"true"}
# normalise PATCH_OLLAMA to a boolean
PATCH_OLLAMA=$(echo "$PATCH_OLLAMA" | tr '[:upper:]' '[:lower:]')
BUILD_NEW_RUNNERS=${BUILD_NEW_RUNNERS:-"false"}

macOSSDK=$(xcrun --show-sdk-path)

export OLLAMA_DEBUG=0
export GIN_MODE=release
export macOSSDK
export ACCELERATE_FRAMEWORK="${macOSSDK}/System/Library/Frameworks/Accelerate.framework"
export FOUNDATION_FRAMEWORK="${macOSSDK}/System/Library/Frameworks/Foundation.framework"
export VECLIB_FRAMEWORK="${macOSSDK}/System/Library/Frameworks/vecLib.framework"
export CLBLAST_FRAMEWORK="/opt/homebrew/Cellar/clblast"
export CLBlast_DIR="/opt/homebrew/lib/cmake/CLBlast"
export BLAS_INCLUDE_DIRS="${CLBLAST_FRAMEWORK},${VECLIB_FRAMEWORK},${ACCELERATE_FRAMEWORK},${FOUNDATION_FRAMEWORK},/opt/homebrew/Cellar/openblas"
export BUILD_LLAMA_CPP_FIRST=${BUILD_LLAMA_CPP_FIRST:-true}
export OLLAMA_MAX_LOADED_MODELS=3
export OLLAMA_KEEP_ALIVE='8h'
export OLLAMA_ORIGINS='http://localhost:*,https://localhost:*,app://obsidian.md*,app://*'
export OLLAMA_CACHE_TYPE_K=q8_0
export OLLAMA_CACHE_TYPE_V=q8_0
export OLLAMA_FLASH_ATTENTION=1
export CGO_LDFLAGS="-Wl,-no_warn_duplicate_libraries"

if [ "$BUILD_NEW_RUNNERS" == "true" ]; then
  export OLLAMA_NEW_RUNNERS=1
fi

# a function that takes input (error output from another command), and stores it in a variable for printing later
function store_error() {
  errors+=("""  - Stored error from line $LINENO: $1""")
}

trap 'store_error "Error on line $LINENO, last command: $BASH_COMMAND"' ERR

# absolute path to ./ollama/ollama_patches.diff
PATCH_DIFF="${HOME}/git/sammcj/scripts/ollama/ollama_patches.diff"

function patch_llama() {
  # custom patches for llama.cpp
  # Take a PR to llama.cpp, e.g. https://github.com/ggerganov/llama.cpp/pull/6707/files, get the fork and branch being requested to merge and apply it to the local llama.cpp (llm/llama.cpp)
  PRs=(
    # "https://github.com/ggerganov/llama.cpp/pull/7154"
    # "https://github.com/ggerganov/llama.cpp/pull/7305" # add server support for the RPC server
  )

  cd "$OLLAMA_GIT_DIR/llm/llama.cpp" || exit

  for PR in "${PRs[@]}"; do
    tput setaf 7
    echo "------------------------------"
    echo "Applying patch from $PR:"
    echo "------------------------------"
    tput sgr0
    curl -sSL "$PR.diff" | git apply --check --
    # if doesn't apply cleanly, pause and let the user decide to continue or not
    if [ $? -ne 0 ]; then
      read -p "Patch from $PR failed to apply cleanly, continue? [y/N] " -n 1 -r

      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        store_error "Patch from $PR failed to apply cleanly, skipping..."
        continue
      fi
    fi
  done
}

function build_llama_cpp() {
  # this function builds the standalone llama.cpp project - NOT the one that Ollama uses, it's just handy to have as well
  if [ "$BUILD_LLAMA_CPP_FIRST" == true ]; then
    echo "skipping llama.cpp build"
    return
  fi

  pushd "${LLAMA_GIT_DIR}" || return
  local gitstatus
  gitstatus=$(git pull)
  if [[ "$gitstatus" == "Already up to date." ]]; then
    echo "No updates to llama.cpp found"
  else
    echo "Updates to llama.cpp found, building and installing"
    git reset --hard HEAD
    git pull

    cmake -B build -Wno-dev \
      -DLLAMA_CUDA=off -DLLAMA_METAL=on -DLLAMA_ACCELERATE=on -DLLAMA_CLBLAST=on -DLLAMA_F16C=on -DLLAMA_RPC=on -DBUILD_SHARED_LIBS=on -DGGML_SCHED_MAX_COPIES=6 \
      -DLLAMA_BLAS_VENDOR=Apple -DLLAMA_BUILD_EXAMPLES=on -DLLAMA_BUILD_TESTS=on -DLLAMA_BUILD_SERVER=on -DLLAMA_CCACHE=on \
      -DLLAMA_ALL_WARNINGS=off -DLLAMA_CURL=on -DLLAMA_METAL_EMBED_LIBRARY=on -DLLAMA_NATIVE=on -DLLAMA_SERVER_VERBOSE=on \
      -DLLAMA_OPENMP=off \
      -DLLAMA_CLBlast_DIR="${CLBlast_DIR}" -DLLAMA_ACCELERATE_FRAMEWORK="${ACCELERATE_FRAMEWORK}" -DLLAMA_FOUNDATION_FRAMEWORK="${FOUNDATION_FRAMEWORK}" &&
      cmake --build build -j 8 &&
      cd build &&
      make -j 8 &&
      make install

    echo "****************************"
    echo "Completed building llama.cpp"
    echo "****************************"
  fi
  popd || return
}

function patch_ollama() {
  if [ "$PATCH_OLLAMA" != true ]; then
    echo "skipping patching of ollama build config"
    return
  fi

  echo "---"
  # echo "TEMPORARY patch of IQ3_XS etc..."
  # git remote add mann1x https://github.com/mann1x/ollama.git || true
  # git fetch mann1x
  # merge non-interactively
  # git merge upstream/mannix-gguf --no-edit
  # echo "patched main with https://github.com/mann1x/ollama.git / mannix-gguf"
  echo "---"

  echo "patching ollama with Sams tweaks"

  # # apply the diff patch
  cd "$OLLAMA_GIT_DIR/llm/llama.cpp" || exit
  # git apply --check "$PATCH_DIFF" || exit 1
  # git apply "$PATCH_DIFF" || exit 1

  # git remote add sammcj https://github.com/sammcj/ollama.git
  # git fetch sammcj
  # git branch -a

  # git checkout sammcj/main llm/server.go
  # git checkout sammcj/main llm/ext_server/server.cpp
  # git checkout sammcj/main api/types.go

  # update golang modules
  # go get -u

  # replace FlashAttn: false, with FlashAttn: true, in api/types.go
  gsed -i 's/FlashAttn: false,/FlashAttn: true,/g' "$OLLAMA_GIT_DIR"/api/types.go

  # remove broken patches/05-clip-fix.diff
  # rm -f "$OLLAMA_GIT_DIR/llm/patches/05-default-pretokenizer.diff"
  # "$OLLAMA_GIT_DIR"/llm/patches/03-load_exception.diff "$OLLAMA_GIT_DIR"/llm/patches/05-clip-fix.diff
  # rm -f "$OLLAMA_GIT_DIR/llm/patches/01-load-progress.diff"        # fixed in my PATCH_DIFF file
  # rm -f "$OLLAMA_GIT_DIR/llm/patches/05-default-pretokenizer.diff" # no longer needed

  if [ ! -f "$OLLAMA_GIT_DIR/llm/generate/gen_darwin.sh" ]; then
    cp "$OLLAMA_GIT_DIR"/llm/generate/gen_darwin.sh "$OLLAMA_GIT_DIR"/llm/generate/gen_darwin.sh.bak
  fi

  if [ ! -f "$OLLAMA_GIT_DIR/scripts/build_darwin.sh" ]; then
    cp "$OLLAMA_GIT_DIR"/scripts/build_darwin.sh "$OLLAMA_GIT_DIR"/scripts/build_darwin.sh.bak
  fi

  # comment out rm -rf ${LLAMACPP_DIR} in gen_common.sh
  # shellcheck disable=SC2016
  gsed -i 's/rm -rf ${LLAMACPP_DIR}/echo not running rm -rf ${LLAMACPP_DIR}/g' "$OLLAMA_GIT_DIR"/llm/generate/gen_common.sh

  echo "This is a gross hack as Ollama's build scripts don't seem to honour CMAKE variables properly"
  sed -i '' "s/-DLLAMA_ACCELERATE=on/-DLLAMA_ALL_WARNINGS_3RD_PARTY=off -DLLAMA_ALL_WARNINGS=off -DLLAMA_ACCELERATE=on -DLLAMA_SCHED_MAX_COPIES=6 -DLLAMA_METAL_MACOSX_VERSION_MIN=14.2 -DLLAMA_NATIVE=on  -DLLAMA_F16C=on -DLLAMA_FP16_VA=on -DLLAMA_NEON=on -DLLAMA_ARM_FMA=on -DLLAMA_CURL=on -DLLAMA_OPENMP=off -Wno-dev/g" "$OLLAMA_GIT_DIR"/llm/generate/gen_darwin.sh

  # patch the ggml build as well
  sed -i '' "s/CMAKE_DEFS='-DCMAKE_OSX_DEPLOYMENT_TARGET=11.3 -DCMAKE_SYSTEM_NAME=Darwin -DBUILD_SHARED_LIBS=off -DCMAKE_SYSTEM_PROCESSOR=arm64 -DCMAKE_OSX_ARCHITECTURES=arm64 -DLLAMA_METAL=off -DLLAMA_ACCELERATE=off -DLLAMA_AVX=off -DLLAMA_AVX2=off -DLLAMA_AVX512=off -DLLAMA_FMA=off -DLLAMA_F16C=off -DCMAKE_BUILD_TYPE=Release -DLLAMA_SERVER_VERBOSE=off '/CMAKE_DEFS='-DCMAKE_OSX_DEPLOYMENT_TARGET=11.3 -DCMAKE_SYSTEM_NAME=Darwin -DBUILD_SHARED_LIBS=off -DCMAKE_SYSTEM_PROCESSOR=arm64 -DCMAKE_OSX_ARCHITECTURES=arm64 -DLLAMA_METAL=off -DLLAMA_ACCELERATE=off -DLLAMA_AVX=off -DLLAMA_AVX2=off -DLLAMA_AVX512=off -DLLAMA_FMA=off -DLLAMA_F16C=off -DCMAKE_BUILD_TYPE=Release -DLLAMA_SERVER_VERBOSE=off -DLLAMA_ACCELERATE=on -DLLAMA_SCHED_MAX_COPIES=6 -DLLAMA_METAL_MACOSX_VERSION_MIN=14.2 -DLLAMA_NATIVE=on -DLLAMA_F16C=on -DLLAMA_FP16_VA=on -DLLAMA_NEON=on -DLLAMA_ARM_FMA=on -DLLAMA_RPC=off -DLLAMA_OPENMP=off '/g" "$OLLAMA_GIT_DIR"/llm/generate/gen_darwin.sh

  # shellcheck disable=SC2016
  gsed -i 's/-DCMAKE_OSX_DEPLOYMENT_TARGET=11.3 -DCMAKE_SYSTEM_NAME=Darwin -DBUILD_SHARED_LIBS=off -DCMAKE_SYSTEM_PROCESSOR=${ARCH} -DCMAKE_OSX_ARCHITECTURES=${ARCH} -DLLAMA_METAL=off -DLLAMA_ACCELERATE=off -DLLAMA_AVX=off -DLLAMA_AVX2=off -DLLAMA_AVX512=off -DLLAMA_FMA=off -DLLAMA_F16C=off ${CMAKE_DEFS}/-DCMAKE_OSX_DEPLOYMENT_TARGET=11.3 -DCMAKE_SYSTEM_NAME=Darwin -DBUILD_SHARED_LIBS=off -DCMAKE_SYSTEM_PROCESSOR=${ARCH} -DCMAKE_OSX_ARCHITECTURES=${ARCH} -DLLAMA_METAL=on -DLLAMA_ACCELERATE=off -DLLAMA_AVX=off -DLLAMA_AVX2=off -DLLAMA_AVX512=off -DLLAMA_FMA=off -DLLAMA_F16C=off -DLLAMA_NEON=on -DLLAMA_ARM_FMA=on -DLLAMA_NATIVE=on -DLLAMA_RPC=off -DLLAMA_OPENMP=off -DLLAMA_OPENMP=off ${CMAKE_DEFS}/g' "$OLLAMA_GIT_DIR"/llm/generate/gen_darwin.sh

  gsed -i 's/cparams.flash_attn       = params.flash_attn;/cparams.flash_attn       = 1;/g' "$OLLAMA_GIT_DIR"/llm/llama.cpp/llama.cpp

  # add export BLAS_INCLUDE_DIRS=$BLAS_INCLUDE_DIRS to the second line of the gen_darwin.sh and scripts/build_darwin.sh files
  gsed -i '2i export BLAS_INCLUDE_DIRS='"$BLAS_INCLUDE_DIRS"'' "$OLLAMA_GIT_DIR"/llm/generate/gen_darwin.sh
  gsed -i '2i export BLAS_INCLUDE_DIRS='"$BLAS_INCLUDE_DIRS"'' "$OLLAMA_GIT_DIR"/scripts/build_darwin.sh

  # set ldflags to disable warnings spamming the output
  gsed -i '2i export LDFLAGS="-w"' "$OLLAMA_GIT_DIR"/llm/generate/gen_darwin.sh
  gsed -i '2i export LDFLAGS="-w"' "$OLLAMA_GIT_DIR"/scripts/build_darwin.sh

  # Set the default NumBatch (n_batch / --batch-size) from the default of 'NumBatch:  512,' to 'NumBatch:  2048,' in api/types.go
  gsed -i 's/NumBatch:  512,/NumBatch:  1024,/g' "$OLLAMA_GIT_DIR"/api/types.go

}

function build_cli() {
  echo "building ollama cli"
  cd "$OLLAMA_GIT_DIR" || exit

  mkdir -p dist
  VERSION=$VERSION BLAS_INCLUDE_DIRS=$BLAS_INCLUDE_DIRS go generate ./... || exit 1
  if [ "$OLLAMA_NEW_RUNNERS" == "1" ]; then
    make -C llama -j 8 || exit 1
  fi
  VERSION=$VERSION BLAS_INCLUDE_DIRS=$BLAS_INCLUDE_DIRS go build -o dist/ollama . || exit 1
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
    cd "$BASE_DIR" || exit
    # git clone -j6 https://github.com/ollama/ollama.git --depth=1

    # Temporary for Quantisation PR
    git checkout feature/kv-quant
    if [ "$BUILD_NEW_RUNNERS" == "true" ]; then
      git checkout feature/kv-quant-newrunners
    else
      git clone -j6 https://github.com/sammcj/ollama.git --depth=1
    fi
  fi

  echo "updating ollama git repo"
  cd "$OLLAMA_GIT_DIR" || exit
  rm -rf llm/llama.cpp dist ollama llm/build macapp/out
  git reset --hard HEAD

  set -e

  git fetch --tags --force
  git pull
  git submodule init
  git submodule sync
  git rebase --abort
  cd llm/llama.cpp || exit
  git reset --hard HEAD

  # Temporary for Quantisation PR
  if [ "$BUILD_NEW_RUNNERS" == "true" ]; then
    git checkout feature/kv-quant-newrunners
  else
    git checkout feature/kv-quant
  fi
  cd "$OLLAMA_GIT_DIR" || exit

  set +e
}

function set_version() {
  cd "$OLLAMA_GIT_DIR" || exit
  VERSION=$(git describe --tags --always)
  export VERSION
  echo "Ollama version (from git tag): $VERSION"

  # replace the version in the app's version/version.go (defaults to var Version string = "0.0.0")
  # sed -i '' "s/var Version string = \"0.0.0\"/var Version string = \"$VERSION\"/g" "$OLLAMA_GIT_DIR"/version/version.go

  # replace the version in the app's package.json
  # sed -i '' "s/\"version\": \"0.0.0\"/\"version\": \"$VERSION\"/g" "$OLLAMA_GIT_DIR"/macapp/package.json
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

  if [ -z "$(launchctl getenv OLLAMA_CACHE_TYPE_K)" ]; then
    echo "setting OLLAMA_CACHE_TYPE_K"
    launchctl setenv OLLAMA_CACHE_TYPE_K "$OLLAMA_CACHE_TYPE_K"
  fi

  if [ -z "$(launchctl getenv OLLAMA_CACHE_TYPE_V)" ]; then
    echo "setting OLLAMA_CACHE_TYPE_V"
    launchctl setenv OLLAMA_CACHE_TYPE_V "$OLLAMA_CACHE_TYPE_V"
  fi

  if [ -z "$(launchctl getenv OLLAMA_MAX_LOADED_MODELS)" ]; then
    echo "setting OLLAMA_MAX_LOADED_MODELS"
    launchctl setenv OLLAMA_MAX_LOADED_MODELS "$OLLAMA_MAX_LOADED_MODELS"
  fi

  if [ -z "$(launchctl getenv OLLAMA_KEEP_ALIVE)" ]; then
    echo "setting OLLAMA_KEEP_ALIVE"
    launchctl setenv OLLAMA_KEEP_ALIVE "$OLLAMA_KEEP_ALIVE"
  fi

  # if OLLAMA_WAS_RUNNING=true, restart the app
  if [ "$OLLAMA_WAS_RUNNING" = true ]; then
    echo "Ollama was running, restarting..."
    open "/Applications/Ollama.app"
  fi
  # sleep 1 && ollama list
  # ./dist/ollama serve
}

# cleanup first
rm -rf /Users/samm/git/ollama-fork/.git/modules/llama.cpp/rebase-apply || true

build_llama_cpp || store_error "Failed to build llama.cpp standalone"
update_git || store_error "Failed to update git"
set_version || store_error "Failed to set version"
patch_ollama || store_error "Failed to patch ollama"
# patch_llama || store_error "Failed to patch llama"
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
