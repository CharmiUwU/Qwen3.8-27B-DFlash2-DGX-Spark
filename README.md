# Qwen3.8-27B DFlash2 on one DGX Spark

<p align="center">
  <sub>DFlash2 extension by <a href="https://github.com/CharmiUwU">CharmiUwU</a></sub>
  <br>
  <sub>based on the original <a href="https://github.com/MiaAI-Lab/Qwen3.8-27B-SGLang-DGX-Spark">Qwen3.8 DGX Spark recipe by MiaAI-Lab</a></sub>
  <br><br>
  <a href="LICENSE"><img src="https://img.shields.io/badge/recipe-MIT-blue.svg" alt="MIT recipe license"></a>
  <a href="LICENSES/Apache-2.0.txt"><img src="https://img.shields.io/badge/overlay-Apache--2.0-green.svg" alt="Apache 2.0 overlay license"></a>
  <img src="https://img.shields.io/badge/hardware-DGX%20Spark-76B900?logo=nvidia&logoColor=white" alt="NVIDIA DGX Spark">
  <img src="https://img.shields.io/badge/speculative-DFlash2-orange" alt="DFlash2">
</p>

> [!IMPORTANT]
> **Primary base credit:** this repository is a DFlash2 extension of
> [MiaAI-Lab/Qwen3.8-27B-SGLang-DGX-Spark](https://github.com/MiaAI-Lab/Qwen3.8-27B-SGLang-DGX-Spark).
> MiaAI-Lab created the Qwen3.8-on-DGX-Spark foundation used here: the
> model-specific SGLang serving scaffold, GB10 defaults, NVFP4 target path,
> reasoning/tool setup, and DSpark/MTP benchmarking lineage. This repository
> adds the DFlash2 integration, quantized-selector compatibility overlay,
> exact-revision packaging, validation, and public operational tooling.

One-node NVIDIA DGX Spark recipe for
[`RadixArk/Qwen3.8-27B-NVFP4`](https://huggingface.co/RadixArk/Qwen3.8-27B-NVFP4)
with the official
[`z-lab/Qwen3.8-27B-DFlash2`](https://huggingface.co/z-lab/Qwen3.8-27B-DFlash2)
draft model, served by SGLang with native **262K context**, reasoning, structured
tool calls, and ten concurrent-request slots.

**Default image:**
`lmsysorg/sglang@sha256:febfb971c7352570fc445c466ebd6ffc9d896024958e544a60f2137fd85856b1`

**Measured on the validated profile:** code **56.32 tok/s median**, essay
**28.08 tok/s median**, repetitive count fixture **71.89 tok/s**. Full method,
correctness gates, and caveats: [`AUDIT.md`](AUDIT.md).

The pinned image predates SGLang's DFlash2 merge. This recipe mounts five
audited SGLang modules read-only instead of rebuilding or mutating the image.
Exact commits and hashes: [`overlay/MANIFEST.md`](overlay/MANIFEST.md).

---

## Quick start

Run everything directly on the DGX Spark.

1. **Requirements**

   - NVIDIA DGX Spark / GB10 with 128 GB unified memory
   - Docker with NVIDIA Container Toolkit (`docker run --gpus all` works)
   - `bash`, `curl`, and Python 3
   - enough disk for the target, DFlash2 draft, image, and compilation caches

2. **Clone and configure**

   ```bash
   git clone https://github.com/CharmiUwU/Qwen3.8-27B-DFlash2-DGX-Spark.git
   cd Qwen3.8-27B-DFlash2-DGX-Spark
   cp .env.example .env
   ```

   The sample already contains the validated profile. A Hugging Face token is
   optional for these public checkpoints but avoids anonymous rate limits:

   ```bash
   export HF_TOKEN=hf_your_token
   ```

3. **Pull the exact image**

   ```bash
   docker pull lmsysorg/sglang@sha256:febfb971c7352570fc445c466ebd6ffc9d896024958e544a60f2137fd85856b1
   ```

4. **Run CPU-only integrity gates**

   ```bash
   bash scripts/ci-validate.sh
   ```

   This checks shell syntax, compiles every Python file, validates the five
   overlay checksums, checks runtime pins, and scans for accidental private
   paths, LAN addresses, keys, or tokens. It does not start the GPU server.

5. **Start**

   ```bash
   ./start-qwen38-dflash2.sh
   ```

   The first start downloads both checkpoints and can take a while. Later boots
   reuse the repo-local `.cache/` volumes. Start exits **3** if the same
   container is already running; this is intentional.

6. **Verify the live service**

   ```bash
   ./status-qwen38-dflash2.sh
   ./smoke-qwen38-dflash2.sh
   ```

   Expect model `qwen3.8-27b-sglang`, `max_model_len=262144`, `DFLASH`, eight
   draft/verify tokens, `DFlash2DraftModel`, and completed target/draft verify
   CUDA-graph captures.

API: `http://DGX_SPARK_IP:8888/v1`. Local clients use
`http://127.0.0.1:8888/v1`.

Day-to-day operations:

```bash
./status-qwen38-dflash2.sh
./logs-qwen38-dflash2.sh
./stop-qwen38-dflash2.sh
```

---

## Default profile

| Knob | Validated default |
| --- | --- |
| Hardware | one NVIDIA DGX Spark / GB10 / aarch64 |
| Image | exact digest `febfb971...` |
| Target | `RadixArk/Qwen3.8-27B-NVFP4@554ebba9b5f1b79dc11246341960360e6ef05ef4` |
| Draft | `z-lab/Qwen3.8-27B-DFlash2@50307d4c4cde6860d4eee73e2547cd786fe8e8a4` |
| Served model | `qwen3.8-27b-sglang` |
| Context ceiling | `262144` native; YaRN off |
| Concurrent requests | `10` |
| Speculative decoding | `DFLASH`, checkpoint block size 8 |
| Target weights | NVFP4 / ModelOpt |
| KV cache | FP8 E4M3 |
| Mamba state | BF16, `extra_buffer`, 50 slots |
| Prefill chunk | 8192 tokens |
| Static memory fraction | 0.90 |
| CPU affinity | GB10 Cortex-X5 cores `5-9,15-19` |
| Graphs | target/draft verify enabled; prefill disabled |
| Reasoning | Qwen3 parser; thinking on by model default |
| Tools | `qwen3_coder` parser |
| Docker restart | `no` — explicit lifecycle control |

The configuration is deliberately pinned. Exact reproduction matters more than
supporting every model/image combination in one script.

---

## `.env` switches

Copy [`.env.example`](.env.example) to `.env`. Existing shell variables win,
so a one-shot override is predictable:

```bash
PORT=9000 ./start-qwen38-dflash2.sh
```

Restart the container after changing serving options.

### Model and runtime pins

| Variable | Default | What it does |
| --- | --- | --- |
| `SGLANG_IMAGE` | exact validated digest | Image whose installed package matches the overlay. |
| `ALLOW_UNVALIDATED_IMAGE` | `0` | Set `1` only after rebuilding and revalidating the overlay against another image. |
| `TARGET_MODEL` | `RadixArk/Qwen3.8-27B-NVFP4` | NVFP4 target repository. |
| `TARGET_REVISION` | `554ebba9...` | Exact target snapshot. |
| `DFLASH2_MODEL` | `z-lab/Qwen3.8-27B-DFlash2` | Official Qwen3.8 DFlash2 draft. |
| `DFLASH2_REVISION` | `50307d4...` | Exact draft snapshot. |
| `SERVED_MODEL_NAME` | `qwen3.8-27b-sglang` | Model name clients send in API requests. |

### Serving shape

| Variable | Default | What it does |
| --- | --- | --- |
| `HOST` / `PORT` | `0.0.0.0` / `8888` | API bind. |
| `CONTEXT_LENGTH` | `262144` | Native context. This recipe rejects values above 262K. |
| `MAX_CONCURRENT_REQUESTS` | `10` | Scheduler cap and input to Mamba-pool sizing. |
| `CHUNKED_PREFILL` | `8192` | Prefill chunk size. |
| `MEM_FRACTION_STATIC` | `0.90` | SGLang static-memory fraction. |
| `CPUSET` | `5-9,15-19` | Pins container processes to GB10 performance cores; empty disables affinity. |
| `MAMBA_SKIP_DECODE_LOCK` | `0` | `1` subtracts one Mamba state slot per request. |
| `RESTART_POLICY` | `no` | Docker restart policy. |
| `HF_CACHE` / `TRITON_CACHE` | repo-local `.cache/` | Persistent cache locations. |
| `DFLASH2_EXTRA` | empty | Advanced SGLang flags appended last; outside the validated profile. |

DFlash2 requires `--mamba-radix-cache-strategy extra_buffer` in this path. The
launch computes:

```text
max_mamba_cache_size = MAX_CONCURRENT_REQUESTS × (5 - MAMBA_SKIP_DECODE_LOCK)
```

The default is 50 slots. The speculative verify window is separate.

---

## How the DFlash2 overlay works

SGLang [PR #35371](https://github.com/sgl-project/sglang/pull/35371) added the
DFlash2 local-convolution and candidate-selector path after the pinned Qwen3.8
image was built. The NVFP4 target also needs quantized LM-head selector support
from the work in [PR #35462](https://github.com/sgl-project/sglang/pull/35462).

Rather than replace the image's custom Qwen3.8 package, this recipe mounts five
three-way-merged files over the matching paths inside the container:

```text
overlay/sglang/kernels/ops/speculative/dflash.py
overlay/sglang/srt/model_executor/model_runner_components/spec_aux_hidden_state.py
overlay/sglang/srt/models/dflash.py
overlay/sglang/srt/speculative/dflash_utils.py
overlay/sglang/srt/speculative/dflash_worker_v2.py
```

All mounts are read-only. `scripts/verify-overlay-sources.sh` checks exact
SHA-256 values before every normal launch. See
[`docs/IMPLEMENTATION.md`](docs/IMPLEMENTATION.md) for the merge logic, graph
behavior, Mamba sizing, and safe upgrade procedure.

Do not use this overlay with a different image merely by bypassing the digest
guard. SGLang internal interfaces change quickly; a successful Python import is
necessary but not sufficient.

---

## What speed to expect

Live on one DGX Spark with the default profile:

| Workload | Same-boot result |
| --- | --- |
| Code — LRUCache implementation + test | **56.32 tok/s median** (55.16–57.39, n=3) |
| Technical essay — Babbage to GPUs | **28.08 tok/s median** (28.07–28.38, n=3) |
| Warm count-to-300 | **71.89 tok/s**, 1,391 tokens |

Run the included delta benchmark:

```bash
python3 bench/ndec.py --runs 3
```

From another machine:

```bash
API_BASE=http://DGX_SPARK_IP:8888/v1 python3 bench/ndec.py --runs 3
```

Compare changes only in the same boot window. Power/thermal drift and prompt
acceptance move results; small cross-day deltas are not trustworthy. Historical
DSpark and MTP numbers are documented in [`AUDIT.md`](AUDIT.md) as context, not
as an exact DFlash2 A/B.

---

## Thinking and tool calling

Thinking is on by the model's default chat template. SGLang exposes it as
`reasoning_content` through `--reasoning-parser qwen3`.

Disable thinking per request:

```json
{
  "model": "qwen3.8-27b-sglang",
  "messages": [{"role": "user", "content": "Write a haiku about GB10."}],
  "temperature": 0.7,
  "top_p": 0.8,
  "presence_penalty": 1.5,
  "chat_template_kwargs": {"enable_thinking": false}
}
```

Structured tools use `--tool-call-parser qwen3_coder`; send normal OpenAI
`tools` in the request. The smoke suite verifies both reasoning separation and
a structured `get_weather` call.

Example:

```bash
curl http://127.0.0.1:8888/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "qwen3.8-27b-sglang",
    "messages": [{"role": "user", "content": "What is 17*23?"}],
    "max_tokens": 128
  }'
```

---

## Context and memory

This public DFlash2 lane intentionally stays at native 262K. The target model
has a documented YaRN path above native context, but target-only rope overrides
were not validated with this draft-model configuration. The launch script
rejects context above 262,144 instead of silently entering an untested path.

At the validated boot, SGLang allocated 1,652,907 KV tokens after loading the
target, the 3.85 GB DFlash2 draft, the Mamba pool, and both verify graphs. Ten
concurrent requests are scheduler slots, not ten reservations of the full 262K
ceiling: live requests still share the finite KV pool.

---

## Logs and troubleshooting

Follow logs:

```bash
./logs-qwen38-dflash2.sh
```

Finite tail without following:

```bash
FOLLOW=0 LINES=300 ./logs-qwen38-dflash2.sh
```

Healthy boot markers include:

```text
speculative_algorithm='DFLASH'
speculative_num_draft_tokens=8
type=DFlash2DraftModel
DFLASH fused KV materialization enabled
Capture target verify CUDA graph end
Capture draft verify CUDA graph end
max_mamba_cache_size=50
```

Common issues:

- **Overlay checksum mismatch:** restore the tracked file. Do not launch an
  unknown merge by setting `SKIP_OVERLAY_VERIFY=1` unless you are developing
  and will rerun the complete audit.
- **Different image rejected:** expected. Rebuild the overlay against that
  image before setting `ALLOW_UNVALIDATED_IMAGE=1`.
- **Container exits during load:** inspect `docker logs qwen3.8-27b-dflash2`.
  Common causes are an incomplete checkpoint, a wrong image architecture, or
  insufficient available unified memory.
- **Anonymous Hub throttling:** export `HF_TOKEN` and retry. The cache is
  persistent.
- **Port already in use:** set `PORT=9000` for a one-shot launch or change
  `.env` after stopping the existing service.
- **Start returns 3:** the configured container is already running; use the
  status script rather than starting a second copy.

---

## Files

| Path | Purpose |
| --- | --- |
| `.env.example` | Validated configuration template |
| `start-qwen38-dflash2.sh` | Exact-image DFlash2 launch and readiness gate |
| `stop-qwen38-dflash2.sh` | Idempotent stop; retains container logs |
| `status-qwen38-dflash2.sh` | Container, API, and DFlash2 boot markers |
| `logs-qwen38-dflash2.sh` | Follow or tail Docker logs |
| `smoke-qwen38-dflash2.sh` | Models, arithmetic, reasoning, tools, and mixed-batch checks |
| `bench/ndec.py` | Same-prompt two-call delta decode benchmark |
| `overlay/` | Five read-only SGLang modules and exact manifest |
| `scripts/verify-overlay-sources.sh` | Overlay checksum/provenance gate |
| `scripts/ci-validate.sh` | CPU-only syntax, compile, pin, and hygiene gates |
| `docs/IMPLEMENTATION.md` | Merge design, runtime path, and upgrade procedure |
| `AUDIT.md` | Live validation and dated performance |
| `CREDITS.md` | Upstream attribution and license notes |
| `NOTICE.md` | Durable identification of the MiaAI-Lab primary base recipe |

---

## Credits and licenses

**Primary base recipe:**
[MiaAI-Lab/Qwen3.8-27B-SGLang-DGX-Spark](https://github.com/MiaAI-Lab/Qwen3.8-27B-SGLang-DGX-Spark).
Thank you to MiaAI-Lab for publishing the DGX Spark Qwen3.8 recipe this work
extends. Full attribution and the inherited/new contribution breakdown:
[`CREDITS.md`](CREDITS.md).

The recipe scripts and documentation are MIT licensed. The SGLang-derived
overlay retains Apache-2.0 lineage; see [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)
and [`LICENSES/Apache-2.0.txt`](LICENSES/Apache-2.0.txt). Model weights, the
container image, CUDA components, and other dependencies remain separate
upstream artifacts under their own terms.
