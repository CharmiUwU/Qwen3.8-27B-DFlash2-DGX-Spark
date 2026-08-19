#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env}"
# shellcheck source=scripts/load-env.sh
source "${SCRIPT_DIR}/scripts/load-env.sh"
load_recipe_env "${ENV_FILE}"

HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8888}"
SERVED_MODEL_NAME="${SERVED_MODEL_NAME:-qwen3.8-27b-sglang}"
CONCURRENCY="${CONCURRENCY:-4}"
probe_host="${HOST}"
case "${probe_host}" in 0.0.0.0|::|'') probe_host=127.0.0.1 ;; esac
API_BASE="${API_BASE:-http://${probe_host}:${PORT}/v1}"

API_BASE="${API_BASE}" MODEL="${SERVED_MODEL_NAME}" CONCURRENCY="${CONCURRENCY}" python3 - <<'PY'
import concurrent.futures
import json
import os
import urllib.error
import urllib.request

base = os.environ["API_BASE"].rstrip("/")
model = os.environ["MODEL"]
concurrency = int(os.environ["CONCURRENCY"])


def request(path, body=None, timeout=600):
    data = None if body is None else json.dumps(body).encode()
    headers = {} if body is None else {"Content-Type": "application/json"}
    req = urllib.request.Request(base + path, data=data, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode(errors="replace")[:1000]
        raise RuntimeError(f"HTTP {exc.code}: {detail}") from exc


models = request("/models", timeout=15)
entry = next((item for item in models.get("data", []) if item.get("id") == model), None)
assert entry, models
assert entry.get("max_model_len") == 262144, entry
print("ok  model listing:", model, "context=262144")

arithmetic = request(
    "/chat/completions",
    {
        "model": model,
        "messages": [{"role": "user", "content": "What is 17*23? Reply with just the number."}],
        "temperature": 0,
        "max_tokens": 64,
        "chat_template_kwargs": {"enable_thinking": False},
    },
)
content = arithmetic["choices"][0]["message"].get("content") or ""
assert "391" in content, arithmetic
print("ok  greedy arithmetic:", content.strip())

reasoning = request(
    "/chat/completions",
    {
        "model": model,
        "messages": [{"role": "user", "content": "Think briefly, then answer: what is 19*7?"}],
        "temperature": 0,
        "max_tokens": 256,
    },
)
message = reasoning["choices"][0]["message"]
assert message.get("reasoning_content"), message
assert "133" in (message.get("content") or ""), message
print("ok  reasoning_content separated")

tool = request(
    "/chat/completions",
    {
        "model": model,
        "messages": [{"role": "user", "content": "What is the weather in Madrid? Use the tool."}],
        "temperature": 0,
        "max_tokens": 256,
        "tools": [
            {
                "type": "function",
                "function": {
                    "name": "get_weather",
                    "description": "Get current weather",
                    "parameters": {
                        "type": "object",
                        "properties": {"city": {"type": "string"}},
                        "required": ["city"],
                    },
                },
            }
        ],
    },
)
calls = tool["choices"][0]["message"].get("tool_calls") or []
assert calls and calls[0]["function"]["name"] == "get_weather", tool
assert "Madrid" in calls[0]["function"]["arguments"], calls[0]
print("ok  structured tool call:", calls[0]["function"]["arguments"])


def mixed_request(index):
    sampled = index % 2 == 1
    body = {
        "model": model,
        "messages": [{"role": "user", "content": f"Reply with OK {index}."}],
        "max_tokens": 48,
        "temperature": 0.7 if sampled else 0,
        "chat_template_kwargs": {"enable_thinking": False},
    }
    if sampled:
        body.update({"top_p": 0.8, "presence_penalty": 1.0})
    result = request("/chat/completions", body)
    text = result["choices"][0]["message"].get("content") or ""
    assert text.strip(), result
    return index, text.strip()


with concurrent.futures.ThreadPoolExecutor(max_workers=concurrency) as pool:
    results = list(pool.map(mixed_request, range(1, concurrency + 1)))
print(f"ok  mixed greedy/sampled batch: {len(results)}/{concurrency}")
print("Smoke suite passed.")
PY
