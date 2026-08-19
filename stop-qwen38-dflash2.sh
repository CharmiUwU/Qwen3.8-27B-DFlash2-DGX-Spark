#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env}"
# shellcheck source=scripts/load-env.sh
source "${SCRIPT_DIR}/scripts/load-env.sh"
load_recipe_env "${ENV_FILE}"

CONTAINER_NAME="${CONTAINER_NAME:-qwen3.8-27b-dflash2}"
PID_FILE="${PID_FILE:-${SCRIPT_DIR}/.sglang.pid}"

command -v docker >/dev/null 2>&1 || { echo "docker is not on PATH" >&2; exit 1; }
if ! docker ps -a --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
  echo "Container ${CONTAINER_NAME} does not exist; nothing to stop."
  rm -f "${PID_FILE}"
  exit 0
fi

if docker ps --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
  echo "Stopping ${CONTAINER_NAME}..."
  docker stop "${CONTAINER_NAME}" >/dev/null
  echo "Stopped. The container is retained for docker logs; the next start removes it."
else
  echo "Container ${CONTAINER_NAME} is already stopped."
fi
rm -f "${PID_FILE}"
