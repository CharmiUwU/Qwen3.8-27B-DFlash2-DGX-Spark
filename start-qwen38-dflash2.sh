#!/usr/bin/env bash
set -euo pipefail

# Qwen3.8-27B NVFP4 + DFlash2 on one NVIDIA DGX Spark (GB10/aarch64).
# The five SGLang modules in overlay/ are mounted read-only into the exact
# pinned image. The image, cache, and checkpoints are never modified.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env}"
VALIDATED_IMAGE="lmsysorg/sglang@sha256:febfb971c7352570fc445c466ebd6ffc9d896024958e544a60f2137fd85856b1"

# shellcheck source=scripts/load-env.sh
source "${SCRIPT_DIR}/scripts/load-env.sh"
load_recipe_env "${ENV_FILE}"

SGLANG_IMAGE="${SGLANG_IMAGE:-${VALIDATED_IMAGE}}"
ALLOW_UNVALIDATED_IMAGE="${ALLOW_UNVALIDATED_IMAGE:-0}"
TARGET_MODEL="${TARGET_MODEL:-RadixArk/Qwen3.8-27B-NVFP4}"
TARGET_REVISION="${TARGET_REVISION:-554ebba9b5f1b79dc11246341960360e6ef05ef4}"
DFLASH2_MODEL="${DFLASH2_MODEL:-z-lab/Qwen3.8-27B-DFlash2}"
DFLASH2_REVISION="${DFLASH2_REVISION:-50307d4c4cde6860d4eee73e2547cd786fe8e8a4}"
SERVED_MODEL_NAME="${SERVED_MODEL_NAME:-qwen3.8-27b-sglang}"
CONTAINER_NAME="${CONTAINER_NAME:-qwen3.8-27b-dflash2}"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8888}"
CONTEXT_LENGTH="${CONTEXT_LENGTH:-262144}"
MAX_CONCURRENT_REQUESTS="${MAX_CONCURRENT_REQUESTS:-10}"
CHUNKED_PREFILL="${CHUNKED_PREFILL:-8192}"
MEM_FRACTION_STATIC="${MEM_FRACTION_STATIC:-0.90}"
CPUSET="${CPUSET-5-9,15-19}"
MAMBA_SKIP_DECODE_LOCK="${MAMBA_SKIP_DECODE_LOCK:-0}"
RESTART_POLICY="${RESTART_POLICY:-no}"
START_TIMEOUT="${START_TIMEOUT:-7200}"
HF_CACHE="${HF_CACHE:-${SCRIPT_DIR}/.cache/huggingface}"
TRITON_CACHE="${TRITON_CACHE:-${SCRIPT_DIR}/.cache/triton}"
LOG_FILE="${LOG_FILE:-${SCRIPT_DIR}/.sglang.log}"
PID_FILE="${PID_FILE:-${SCRIPT_DIR}/.sglang.pid}"
OVERLAY_ROOT="${SCRIPT_DIR}/overlay/sglang"

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_uint() {
  local name="$1" value="$2"
  [[ "${value}" =~ ^[0-9]+$ ]] || die "${name} must be an integer, got '${value}'"
}

command -v docker >/dev/null 2>&1 || die "docker is not on PATH"
command -v curl >/dev/null 2>&1 || die "curl is not on PATH"
docker info >/dev/null 2>&1 || die "Docker is not reachable by this user"

case "$(uname -m)" in
  aarch64|arm64) : ;;
  *) printf 'WARNING: this recipe was validated only on DGX Spark aarch64/GB10.\n' >&2 ;;
esac

case "${ALLOW_UNVALIDATED_IMAGE}" in 0|1) : ;; *) die "ALLOW_UNVALIDATED_IMAGE must be 0 or 1" ;; esac
if [[ "${SGLANG_IMAGE}" != "${VALIDATED_IMAGE}" && "${ALLOW_UNVALIDATED_IMAGE}" != "1" ]]; then
  die "SGLANG_IMAGE differs from the validated digest; set ALLOW_UNVALIDATED_IMAGE=1 only after revalidating the overlay"
fi

require_uint PORT "${PORT}"
require_uint CONTEXT_LENGTH "${CONTEXT_LENGTH}"
require_uint MAX_CONCURRENT_REQUESTS "${MAX_CONCURRENT_REQUESTS}"
require_uint CHUNKED_PREFILL "${CHUNKED_PREFILL}"
require_uint START_TIMEOUT "${START_TIMEOUT}"
(( PORT >= 1 && PORT <= 65535 )) || die "PORT must be between 1 and 65535"
(( CONTEXT_LENGTH >= 4096 && CONTEXT_LENGTH <= 262144 )) || die "DFlash2 is validated only for CONTEXT_LENGTH=4096..262144"
(( MAX_CONCURRENT_REQUESTS >= 1 )) || die "MAX_CONCURRENT_REQUESTS must be at least 1"
(( CHUNKED_PREFILL >= 256 )) || die "CHUNKED_PREFILL must be at least 256"
case "${MAMBA_SKIP_DECODE_LOCK}" in 0|1) : ;; *) die "MAMBA_SKIP_DECODE_LOCK must be 0 or 1" ;; esac
case "${RESTART_POLICY}" in no|on-failure|always|unless-stopped) : ;; *) die "unsupported RESTART_POLICY '${RESTART_POLICY}'" ;; esac

# With overlap scheduling, extra_buffer needs base 3 + two ping-pong slots.
# Skip-decode-lock removes one resident state. The verify window is separate.
MAMBA_SLOTS_PER_REQUEST=$((5 - MAMBA_SKIP_DECODE_LOCK))
MAMBA_CACHE_SIZE=$((MAX_CONCURRENT_REQUESTS * MAMBA_SLOTS_PER_REQUEST))

OVERLAY_FILES=(
  "kernels/ops/speculative/dflash.py"
  "srt/model_executor/model_runner_components/spec_aux_hidden_state.py"
  "srt/models/dflash.py"
  "srt/speculative/dflash_utils.py"
  "srt/speculative/dflash_worker_v2.py"
)

if [[ "${SKIP_OVERLAY_VERIFY:-0}" != "1" ]]; then
  "${SCRIPT_DIR}/scripts/verify-overlay-sources.sh"
fi

MOUNT_ARGS=()
for rel in "${OVERLAY_FILES[@]}"; do
  src="${OVERLAY_ROOT}/${rel}"
  dst="/sgl-workspace/sglang/python/sglang/${rel}"
  [[ -f "${src}" ]] || die "missing overlay file ${src}"
  MOUNT_ARGS+=(--mount "type=bind,src=${src},dst=${dst},readonly")
done

if docker ps -a --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
  if docker ps --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
    printf 'Container %s is already running.\n' "${CONTAINER_NAME}"
    printf 'Use ./status-qwen38-dflash2.sh or stop it before a cold start.\n'
    exit 3
  fi
  docker rm "${CONTAINER_NAME}" >/dev/null
fi

mkdir -p "${HF_CACHE}" "${TRITON_CACHE}"
: >"${LOG_FILE}"

printf 'Starting Qwen3.8-27B + DFlash2\n'
printf '  image:       %s\n' "${SGLANG_IMAGE}"
printf '  target:      %s@%s\n' "${TARGET_MODEL}" "${TARGET_REVISION}"
printf '  draft:       %s@%s\n' "${DFLASH2_MODEL}" "${DFLASH2_REVISION}"
printf '  API:         http://%s:%s/v1\n' "${HOST}" "${PORT}"
printf '  context:     %s\n' "${CONTEXT_LENGTH}"
printf '  concurrency: %s (Mamba pool %s slots)\n' "${MAX_CONCURRENT_REQUESTS}" "${MAMBA_CACHE_SIZE}"

DOCKER_ARGS=(
  run -d
  --name "${CONTAINER_NAME}"
  --restart "${RESTART_POLICY}"
  --network host
  --ipc host
  --privileged
  --gpus all
  --shm-size 32g
)
[[ -n "${CPUSET}" ]] && DOCKER_ARGS+=(--cpuset-cpus "${CPUSET}")
DOCKER_ARGS+=(
  -e HF_HOME=/root/.cache/huggingface
  -e TRITON_CACHE_DIR=/root/.triton
  -e "SGLANG_OPT_MAMBA_SKIP_DECODE_LOCK=${MAMBA_SKIP_DECODE_LOCK}"
)
[[ -n "${HF_TOKEN:-}" ]] && DOCKER_ARGS+=(-e "HF_TOKEN=${HF_TOKEN}")
DOCKER_ARGS+=(
  -v "${HF_CACHE}:/root/.cache/huggingface"
  -v "${TRITON_CACHE}:/root/.triton"
  "${MOUNT_ARGS[@]}"
  "${SGLANG_IMAGE}"
  python3 -m sglang.launch_server
  --model-path "${TARGET_MODEL}"
  --revision "${TARGET_REVISION}"
  --served-model-name "${SERVED_MODEL_NAME}"
  --trust-remote-code
  --mem-fraction-static "${MEM_FRACTION_STATIC}"
  --attention-backend flashinfer
  --chunked-prefill-size "${CHUNKED_PREFILL}"
  --disable-prefill-cuda-graph
  --kv-cache-dtype fp8_e4m3
  --mamba-ssm-dtype bfloat16
  --mamba-full-memory-ratio 4.21
  --mamba-radix-cache-strategy extra_buffer
  --max-mamba-cache-size "${MAMBA_CACHE_SIZE}"
  --max-running-requests "${MAX_CONCURRENT_REQUESTS}"
  --context-length "${CONTEXT_LENGTH}"
  --speculative-algorithm DFLASH
  --speculative-draft-model-path "${DFLASH2_MODEL}"
  --speculative-draft-model-revision "${DFLASH2_REVISION}"
  --speculative-num-draft-tokens 8
  --reasoning-parser qwen3
  --tool-call-parser qwen3_coder
  --sampling-defaults model
  --host "${HOST}"
  --port "${PORT}"
)
if [[ -n "${DFLASH2_EXTRA:-}" ]]; then
  read -r -a DFLASH2_EXTRA_ARGS <<< "${DFLASH2_EXTRA}"
  DOCKER_ARGS+=("${DFLASH2_EXTRA_ARGS[@]}")
fi
docker "${DOCKER_ARGS[@]}" >/dev/null

container_id="$(docker inspect -f '{{.Id}}' "${CONTAINER_NAME}")"
printf '%s\n' "${container_id}" >"${PID_FILE}"

log_follow_pid=''
cleanup() {
  if [[ -n "${log_follow_pid}" ]] && kill -0 "${log_follow_pid}" 2>/dev/null; then
    kill "${log_follow_pid}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

docker logs -f "${CONTAINER_NAME}" 2>&1 | tee -a "${LOG_FILE}" &
log_follow_pid=$!

probe_host="${HOST}"
case "${probe_host}" in 0.0.0.0|::|'') probe_host=127.0.0.1 ;; esac
READY_URL="http://${probe_host}:${PORT}/v1/models"
deadline=$((SECONDS + START_TIMEOUT))
printf 'Waiting for readiness at %s\n' "${READY_URL}"
heartbeat=0
until curl -fsS --max-time 5 "${READY_URL}" >/dev/null 2>&1; do
  if ! docker ps --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
    printf 'Container exited during startup.\n' >&2
    docker logs --tail 200 "${CONTAINER_NAME}" >&2 || true
    exit 1
  fi
  (( SECONDS < deadline )) || {
    docker logs --tail 200 "${CONTAINER_NAME}" >&2 || true
    die "timed out after ${START_TIMEOUT}s waiting for SGLang"
  }
  if (( heartbeat % 6 == 0 )); then printf '  still starting...\n'; fi
  heartbeat=$((heartbeat + 1))
  sleep 5
done

docker logs "${CONTAINER_NAME}" 2>&1 | grep "speculative_algorithm='DFLASH'" >/dev/null \
  || die "API became ready but the boot log does not identify DFLASH"

curl -fsS --max-time 10 "${READY_URL}" | python3 -c 'import json,sys
d=json.load(sys.stdin)
expected=sys.argv[1]
assert any(m.get("id")==expected for m in d.get("data",[])), d
print("Ready:", expected, "max_model_len=", d["data"][0].get("max_model_len"))' "${SERVED_MODEL_NAME}"

printf 'OpenAI base URL: http://%s:%s/v1\n' "${probe_host}" "${PORT}"
printf 'Run ./smoke-qwen38-dflash2.sh for arithmetic, reasoning, tools, and concurrency checks.\n'
