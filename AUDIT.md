# Serving audit — one DGX Spark, 2026-08-19

This records the live validation behind the published defaults. It is not a
performance guarantee for every prompt, ambient temperature, power mode, or
future runtime.

## Validated profile

| Item | Value |
| --- | --- |
| Hardware | One NVIDIA DGX Spark, GB10, 128 GB unified memory |
| Target | `RadixArk/Qwen3.8-27B-NVFP4@554ebba9...` |
| Draft | `z-lab/Qwen3.8-27B-DFlash2@50307d4...` |
| Runtime | pinned `lmsysorg/sglang` image digest + five-file read-only overlay |
| Context | 262,144 native |
| Concurrent requests | 10 |
| DFlash block | 8 |
| KV cache | FP8 E4M3; 1,652,907 tokens allocated |
| Mamba | BF16 state, `extra_buffer`, 50 slots |
| Graphs | target verify and draft verify captured; prefill disabled |

## Correctness gates

- Exact API model name and `max_model_len=262144`
- Non-thinking greedy arithmetic (`17 × 23 = 391`)
- Reasoning separated into `reasoning_content`
- Structured `get_weather` tool call with Madrid arguments
- Sampled decoding
- Mixed four-request batch: greedy and sampled requests together
- 700-token code output inspection: coherent, no repetition loop
- No traceback, CUDA error, runtime exception, process death, or OOM in the
  post-benchmark log window

## Measured decode

The `bench/ndec.py` method sends the same prompt twice, at 60 and 600 maximum
completion tokens, then computes `(long_tokens - short_tokens) / (long_time -
short_time)`. This removes most prefill and time-to-first-token cost.

| Probe | Result |
| --- | --- |
| Code, three runs | **56.32 tok/s median** (55.16–57.39) |
| Essay, three runs | **28.08 tok/s median** (28.07–28.38) |
| Warm count-to-300 | **71.89 tok/s**, 1,391 completion tokens in 19.35 s |

The count fixture reached 8/8 acceptance. Code was roughly 6.5/8 and essay
roughly 3/8 in sampled log windows; acceptance is workload-dependent.

Historical measurements from an earlier boot were 51.5 code / 18.3 essay for
DSpark and 34.5 code / 24.1 essay for MTP. Those are context only, not a
controlled same-boot comparison with DFlash2.

## Reproduce

```bash
bash scripts/ci-validate.sh
./start-qwen38-dflash2.sh
./status-qwen38-dflash2.sh
./smoke-qwen38-dflash2.sh
python3 bench/ndec.py --runs 3
```

Run performance comparisons back-to-back on the same boot. DGX Spark power and
thermal drift can move code results enough to invalidate small deltas.
