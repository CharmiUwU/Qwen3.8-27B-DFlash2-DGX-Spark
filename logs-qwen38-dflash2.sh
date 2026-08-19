#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env}"
# shellcheck source=scripts/load-env.sh
source "${SCRIPT_DIR}/scripts/load-env.sh"
load_recipe_env "${ENV_FILE}"

CONTAINER_NAME="${CONTAINER_NAME:-qwen3.8-27b-dflash2}"
LINES="${LINES:-200}"
FOLLOW="${FOLLOW:-1}"
args=(--tail "${LINES}")
[[ "${FOLLOW}" == "1" ]] && args+=(-f)
exec docker logs "${args[@]}" "${CONTAINER_NAME}"
