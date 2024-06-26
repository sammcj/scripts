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
export OLLAMA_NUM_PARALLEL=6
export OLLAMA_MAX_LOADED_MODELS=3
export OLLAMA_KEEP_ALIVE='60m'
export OLLAMA_ORIGINS='http://localhost:*,https://localhost:*,app://obsidian.md*,app://*'
export BUILD_LLAMA_CPP=${BUILD_LLAMA_CPP:-"true"}
export BUILD_OLLAMA=${BUILD_OLLAMA:-"true"}

# a function that takes input (error output from another command), and stores it in a variable for printing later
function store_error() {
  errors+=("""  - Stored error from line $LINENO: $1""")
}

trap 'store_error "Error on line $LINENO"' ERR

# absolute path to ./ollama/ollama_patches.diff
OLLAMA_PATCH_DIFF="${HOME}/git/sammcj/scripts/ollama/ollama_patches.diff"

function patch_llama() {
  # custom patches for llama.cpp
  local llamadir=$1

  # Take a PR to llama.cpp, e.g. https://github.com/ggerganov/llama.cpp/pull/6707/files, get the fork and branch being requested to merge and apply it to the local llama.cpp (llm/llama.cpp)
  PRs=(
    # "https://github.com/ggerganov/llama.cpp/pull/7154"
    # "https://github.com/ggerganov/llama.cpp/pull/7305" # add server support for the RPC backend
  )

  cd "$llamadir" || exit

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
  local macOSSDK
  local llamadir=$1

  macOSSDK=$(xcrun --show-sdk-path)
  ACCELERATE_FRAMEWORK="${macOSSDK}/System/Library/Frameworks/Accelerate.framework"
  FOUNDATION_FRAMEWORK="${macOSSDK}/System/Library/Frameworks/Foundation.framework"
  VECLIB_FRAMEWORK="${macOSSDK}/System/Library/Frameworks/vecLib.framework"
  CLBLAST_FRAMEWORK="/opt/homebrew/Cellar/clblast/1.6.2/"
  BLAS_INCLUDE_DIRS="${CLBLAST_FRAMEWORK},${VECLIB_FRAMEWORK}"
  CLBlast_DIR="/opt/homebrew/lib/cmake/CLBlast"

  pushd "${llamadir}" || return
  local gitstatus
  gitstatus=$(git pull)
  if [[ "$gitstatus" == "Already up to date." ]]; then
    echo "No updates to llama.cpp found"
  else
    echo "Updates to llama.cpp found, building and installing"
    cmake . -Wno-dev \
      -DLLAMA_CUDA=off -DLLAMA_METAL=on -DLLAMA_CLBLAST=on -DLLAMA_F16C=on -DLLAMA_RPC=on -DBUILD_SHARED_LIBS=on \
      -DLLAMA_BLAS_VENDOR=Apple -DLLAMA_BUILD_EXAMPLES=on -DLLAMA_BUILD_TESTS=on -DLLAMA_BUILD_SERVER=on -DLLAMA_CCACHE=on \
      -DLLAMA_ALL_WARNINGS=off -DLLAMA_CURL=on -DLLAMA_METAL_EMBED_LIBRARY=on -DLLAMA_NATIVE=on -DLLAMA_SERVER_VERBOSE=on -DLLAMA_RPC=on \
      -DLLAMA_CLBlast_DIR="${CLBlast_DIR}" -DLLAMA_ACCELERATE_FRAMEWORK="${ACCELERATE_FRAMEWORK}" -DLLAMA_FOUNDATION_FRAMEWORK="${FOUNDATION_FRAMEWORK}" &&
      make -j 12 &&
      make install

    cp "${HOME}/git/llama.cpp/libllama.dylib" "/${HOME}/.wasmedge/lib/libllama.dylib"

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

  echo "patching ollama with Sams tweaks"

  # # apply the diff patch
  cd "$OLLAMA_GIT_DIR" || exit
  git apply "$OLLAMA_PATCH_DIFF" || exit 1

  git remote add sammcj https://github.com/sammcj/ollama.git
  git fetch sammcj
  git branch -a

  git checkout sammcj/main llm/server.go
  git checkout sammcj/main llm/ext_server/server.cpp
  git checkout sammcj/main api/types.go

  # update golang modules
  go get -u

  # replace FlashAttn: false, with FlashAttn: true, in api/types.go
  gsed -i 's/FlashAttn: false,/FlashAttn: true,/g' "$OLLAMA_GIT_DIR"/api/types.go

  # remove broken patches/05-clip-fix.diff
  rm -f "$OLLAMA_GIT_DIR"/llm/patches/03-load_exception.diff "$OLLAMA_GIT_DIR"/llm/patches/05-clip-fix.diff

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
  sed -i '' "s/-DLLAMA_ACCELERATE=on/-DLLAMA_ALL_WARNINGS_3RD_PARTY=off -DLLAMA_ALL_WARNINGS=off -DLLAMA_ACCELERATE=on -DGGML_USE_ACCELERATE=1 -DLLAMA_SCHED_MAX_COPIES=6 -DLLAMA_METAL_MACOSX_VERSION_MIN=14.2 -DLLAMA_NATIVE=on  -DLLAMA_F16C=on -DLLAMA_FP16_VA=on -DLLAMA_NEON=on -DLLAMA_ARM_FMA=on -DLLAMA_CURL=on -DLLAMA_RPC=on -Wno-dev/g" "$OLLAMA_GIT_DIR"/llm/generate/gen_darwin.sh
  # -DLLAMA_FMA=on -DLLAMA_PERF=on # these don't seem to speed anything up
  # Do not enable -DLLAMA_QKK_64=on !!

  # patch the ggml build as well
  sed -i '' "s/CMAKE_DEFS='-DCMAKE_OSX_DEPLOYMENT_TARGET=11.3 -DCMAKE_SYSTEM_NAME=Darwin -DBUILD_SHARED_LIBS=off -DCMAKE_SYSTEM_PROCESSOR=arm64 -DCMAKE_OSX_ARCHITECTURES=arm64 -DLLAMA_METAL=off -DLLAMA_ACCELERATE=off -DLLAMA_AVX=off -DLLAMA_AVX2=off -DLLAMA_AVX512=off -DLLAMA_FMA=off -DLLAMA_F16C=off -DCMAKE_BUILD_TYPE=Release -DLLAMA_SERVER_VERBOSE=off '/CMAKE_DEFS='-DCMAKE_OSX_DEPLOYMENT_TARGET=11.3 -DCMAKE_SYSTEM_NAME=Darwin -DBUILD_SHARED_LIBS=off -DCMAKE_SYSTEM_PROCESSOR=arm64 -DCMAKE_OSX_ARCHITECTURES=arm64 -DLLAMA_METAL=off -DLLAMA_ACCELERATE=off -DLLAMA_AVX=off -DLLAMA_AVX2=off -DLLAMA_AVX512=off -DLLAMA_FMA=off -DLLAMA_F16C=off -DCMAKE_BUILD_TYPE=Release -DLLAMA_SERVER_VERBOSE=off -DLLAMA_ACCELERATE=on -DLLAMA_SCHED_MAX_COPIES=6 -DLLAMA_METAL_MACOSX_VERSION_MIN=14.2 -DLLAMA_NATIVE=on -DLLAMA_F16C=on -DLLAMA_FP16_VA=on -DLLAMA_NEON=on -DLLAMA_ARM_FMA=on -DGGML_USE_ACCELERATE=on '/g" "$OLLAMA_GIT_DIR"/llm/generate/gen_darwin.sh

  # shellcheck disable=SC2016
  gsed -i 's/-DCMAKE_OSX_DEPLOYMENT_TARGET=11.3 -DCMAKE_SYSTEM_NAME=Darwin -DBUILD_SHARED_LIBS=off -DCMAKE_SYSTEM_PROCESSOR=${ARCH} -DCMAKE_OSX_ARCHITECTURES=${ARCH} -DLLAMA_METAL=off -DLLAMA_ACCELERATE=off -DLLAMA_AVX=off -DLLAMA_AVX2=off -DLLAMA_AVX512=off -DLLAMA_FMA=off -DLLAMA_F16C=off ${CMAKE_DEFS}/-DCMAKE_OSX_DEPLOYMENT_TARGET=11.3 -DCMAKE_SYSTEM_NAME=Darwin -DBUILD_SHARED_LIBS=off -DCMAKE_SYSTEM_PROCESSOR=${ARCH} -DCMAKE_OSX_ARCHITECTURES=${ARCH} -DLLAMA_METAL=on -DLLAMA_ACCELERATE=off -DLLAMA_AVX=off -DLLAMA_AVX2=off -DLLAMA_AVX512=off -DLLAMA_FMA=off -DLLAMA_F16C=off -DLLAMA_NEON=on -DLLAMA_ARM_FMA=on -DLLAMA_NATIVE=on -DGGML_USE_ACCELERATE=on ${CMAKE_DEFS}/g' "$OLLAMA_GIT_DIR"/llm/generate/gen_darwin.sh

  # llama_new_context_with_model: flash_attn = 0 should be 1
  # Force flash_attn to be on in the underlying llama.cpp build
  # replace cparams.flash_attn       = params.flash_attn; with cparams.flash_attn       = 1; in llm/llama.cpp/llama.cpp
  gsed -i 's/cparams.flash_attn       = params.flash_attn;/cparams.flash_attn       = 1;/g' "$OLLAMA_GIT_DIR"/llm/llama.cpp/llama.cpp

  # add export BLAS_INCLUDE_DIRS=$BLAS_INCLUDE_DIRS to the second line of the gen_darwin.sh and scripts/build_darwin.sh files
  gsed -i '2i export BLAS_INCLUDE_DIRS='"$BLAS_INCLUDE_DIRS"'' "$OLLAMA_GIT_DIR"/llm/generate/gen_darwin.sh
  gsed -i '2i export BLAS_INCLUDE_DIRS='"$BLAS_INCLUDE_DIRS"'' "$OLLAMA_GIT_DIR"/scripts/build_darwin.sh

  # set ldflags to disable warnings spamming the output
  gsed -i '2i export LDFLAGS="-w"' "$OLLAMA_GIT_DIR"/llm/generate/gen_darwin.sh
  gsed -i '2i export LDFLAGS="-w"' "$OLLAMA_GIT_DIR"/scripts/build_darwin.sh

}

function build_cli() {
  echo "building ollama cli"
  cd "$OLLAMA_GIT_DIR" || exit

  mkdir -p dist
  VERSION=$VERSION BLAS_INCLUDE_DIRS=$BLAS_INCLUDE_DIRS go generate ./... || exit 1
  VERSION=$VERSION BLAS_INCLUDE_DIRS=$BLAS_INCLUDE_DIRS go build -o dist/ollama . || exit 1
  # go run build.go -f
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
    git clone https://github.com/ollama/ollama.git --depth=1
  fi

  echo "updating ollama git repo"
  cd "$OLLAMA_GIT_DIR" || exit
  rm -rf llm/llama.cpp dist ollama llm/build macapp/out
  git reset --hard HEAD

  set -e

  # force pull any tags
  git fetch --tags --force
  git pull
  git submodule init
  git rebase --abort
  git submodule update --remote --rebase --recursive
  cd llm/llama.cpp || exit
  git checkout origin/master
  cd "$OLLAMA_GIT_DIR" || exit

  # shellcheck disable=SC2016
  gsed -i '/git submodule update --force ${LLAMACPP_DIR}/d' "$OLLAMA_GIT_DIR"/llm/generate/gen_common.sh

  set +e
}

function update_llama_cpp_git() {
  llamadir=$1

  if [ ! -d "$llamadir" ]; then
    echo "cloning llama git repo"
    # one directory up from the git repo
    BASE_DIR=$(dirname "$llamadir")
    cd "$BASE_DIR" || exit
    git clone https://github.com/ggerganov/llama.cpp.git --depth=1
  fi

  echo "updating llama.cpp git repo"
  cd "$llamadir" || exit
  git reset --hard HEAD

  set -e

  # force pull any tags
  git fetch --force
  git pull
  git rebase --abort || true
  git checkout origin/master

  set +e
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

  if [ -z "$(launchctl getenv OLLAMA_ORIGINS)" ]; then
    echo "setting OLLAMA_ORIGINS"
    launchctl setenv OLLAMA_ORIGINS "$OLLAMA_ORIGINS"
  fi

  if [ -z "$(launchctl getenv OLLAMA_NUM_PARALLEL)" ]; then
    echo "setting OLLAMA_NUM_PARALLEL"
    launchctl setenv OLLAMA_NUM_PARALLEL "$OLLAMA_NUM_PARALLEL"
  fi

  if [ -z "$(launchctl getenv OLLAMA_MAX_LOADED_MODELS)" ]; then
    echo "setting OLLAMA_MAX_LOADED_MODELS"
    launchctl setenv OLLAMA_MAX_LOADED_MODELS "$OLLAMA_MAX_LOADED_MODELS"
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

if [ "$BUILD_LLAMA_CPP" == "true" ]; then
  update_llama_cpp_git "${HOME}/git/llama.cpp" || store_error "Failed to update llama.cpp git"
  patch_llama "${HOME}/git/llama.cpp" || store_error "Failed to patch llama"
  build_llama_cpp "${HOME}/git/llama.cpp" || store_error "Failed to build llama.cpp standalone"
fi

if [ "$BUILD_OLLAMA" == "true" ]; then
  update_git || store_error "Failed to update git"
  set_version || store_error "Failed to set version"
  patch_llama "${OLLAMA_GIT_DIR}/llm/llama.cpp" || store_error "Failed to patch llama"
  patch_ollama "${OLLAMA_GIT_DIR}/llm/llama.cpp" || store_error "Failed to patch ollama"
  build_cli || store_error "Failed to build ollama cli"
  build_app || store_error "Failed to build ollama app"
  update_fw_rules || store_error "Failed to update firewall rules"
  run_app || store_error "Failed to run app"
fi

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
