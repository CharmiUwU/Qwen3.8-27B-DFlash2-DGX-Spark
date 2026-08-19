#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env}"
# shellcheck source=scripts/load-env.sh
source "${SCRIPT_DIR}/scripts/load-env.sh"
load_recipe_env "${ENV_FILE}"

CONTAINER_NAME="${CONTAINER_NAME:-qwen3.8-27b-dflash2}"
SERVED_MODEL_NAME="${SERVED_MODEL_NAME:-qwen3.8-27b-sglang}"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8888}"
probe_host="${HOST}"
case "${probe_host}" in 0.0.0.0|::|'') probe_host=127.0.0.1 ;; esac
API_URL="${API_URL:-http://${probe_host}:${PORT}/v1/models}"

echo "== container =="
if docker ps -a --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
  docker inspect -f 'name={{.Name}} status={{.State.Status}} restart={{.HostConfig.RestartPolicy.Name}} image={{.Config.Image}}' "${CONTAINER_NAME}"
else
  echo "absent: ${CONTAINER_NAME}"
fi

echo
echo "== API =="
if curl -fsS --max-time 5 "${API_URL}" | python3 -m json.tool; then
  :
else
  echo "not responding: ${API_URL}"
fi

echo
echo "== DFlash2 boot markers =="
docker logs "${CONTAINER_NAME}" 2>&1 | grep -E \
  "speculative_algorithm='DFLASH'|speculative_num_draft_tokens=8|max_mamba_cache_size=|DFlash2DraftModel|DFLASH fused KV|Capture (target|draft) verify CUDA graph end" \
  | tail -20 || true

echo
echo "expected served model: ${SERVED_MODEL_NAME}"
