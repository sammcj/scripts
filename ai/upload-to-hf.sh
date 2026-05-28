#!/usr/bin/env bash
set -uo pipefail

if [[ -z ${HF_TOKEN:-} ]]; then
    HF_TOKEN=$(hf auth token 2>/dev/null || true)
fi
if [[ -z ${HF_TOKEN:-} && -r $HOME/.cache/huggingface/token ]]; then
    HF_TOKEN=$(<"$HOME/.cache/huggingface/token")
fi
export HF_TOKEN
if [[ -z ${HF_TOKEN:-} ]]; then
    echo "Could not obtain HF_TOKEN. Tried: \$HF_TOKEN env, 'hf auth token', ~/.cache/huggingface/token" >&2
    exit 1
fi

hf_wait_for_ratelimit() {
    local threshold=${1:-10}  # min % remaining
    while :; do
        local headers ratelimit policy r q t
        headers=$(curl -sSI -H "Authorization: Bearer $HF_TOKEN" https://huggingface.co/api/whoami-v2) \
            || { echo "rate-limit probe: curl failed (proceeding)" >&2; return 0; }
        ratelimit=$(printf '%s\n' "$headers" | grep -i '^ratelimit:'        || true)
        policy=$(   printf '%s\n' "$headers" | grep -i '^ratelimit-policy:' || true)
        r=$(printf '%s' "$ratelimit" | grep -oE 'r=[0-9]+' | cut -d= -f2)
        t=$(printf '%s' "$ratelimit" | grep -oE 't=[0-9]+' | cut -d= -f2)
        q=$(printf '%s' "$policy"    | grep -oE 'q=[0-9]+' | cut -d= -f2)
        if [[ -z $r || -z $q ]]; then
            echo "rate-limit probe: no header in response (proceeding)" >&2
            return 0
        fi
        if (( r * 100 / q < threshold )); then
            echo "HF rate-limit low: ${r}/${q} remaining (resets in ${t}s); sleeping 30s" >&2
            sleep 30
        else
            echo "HF rate-limit OK: ${r}/${q} remaining" >&2
            return 0
        fi
    done
}

echo "uploading Base 2b"
hf_wait_for_ratelimit
uvx hf upload-large-folder \
  smcleod/ibm-granite-speech-4.1-2b-onnx \
  /Users/samm/git/sammcj/granite-speech-4.1-onnx/bundles/ibm-granite-speech-4.1-2b-onnx \
  --repo-type model

echo "uploading Plus 2b"
hf_wait_for_ratelimit
uvx hf upload-large-folder \
  smcleod/ibm-granite-speech-4.1-2b-plus-onnx \
  /Users/samm/git/sammcj/granite-speech-4.1-onnx/bundles/ibm-granite-speech-4.1-2b-plus-onnx \
  --repo-type model

echo "uploading NAR"
hf_wait_for_ratelimit
uvx hf upload-large-folder \
  smcleod/ibm-granite-speech-4.1-2b-nar-onnx \
  /Users/samm/git/sammcj/granite-speech-4.1-onnx/bundles/ibm-granite-speech-4.1-2b-nar-onnx \
  --repo-type model
