# Implementation notes

## Why an overlay exists

The validated Qwen3.8 image is model-specific and was built from SGLang commit
`c4271c3fe1262fc2adbd162c33b25de5255251c5`. DFlash2 merged later in SGLang
commit `c14312a66420b75ca9a11bf1817c4db1fa26b097`. Replacing the entire installed
package would discard the image's Qwen3.8 customizations, while rebuilding a
new aarch64 image would add a large, difficult-to-audit variable.

This recipe therefore overlays five source files at container creation time.
Every mount is read-only, and the launch refuses an unvalidated image digest by
default.

## Runtime path

1. Load the NVFP4 target at its exact Hugging Face revision.
2. Load `DFlash2DraftModel` from its exact revision.
3. Materialize target KV from five target layers into the draft path.
4. Draft and verify eight-token blocks using `DFLASH`.
5. Serve the normal OpenAI-compatible SGLang API with Qwen reasoning and tool
   parsers enabled.

The live boot confirmed:

- `DFlash2DraftModel`, block size 8
- fused target-KV materialization: 5 layers, 8 KV heads, head dimension 128
- target verify CUDA graph captured
- draft verify CUDA graph captured
- prefill CUDA graph disabled
- native context 262,144
- 10 running requests, 50 Mamba state slots
- 1,652,907 KV-cache tokens

The target LM head is ModelOpt-quantized. The selector-scoring change from
SGLang commit `3be1b327...` uses that quant method correctly; the target
selector itself remains eager. Target and draft verification still use their
captured CUDA graphs.

## Mamba state-pool calculation

Qwen3.8 is a hybrid GDN model. With overlap scheduling, the DFlash2-required
`extra_buffer` strategy uses five resident state slots per request: base three
plus two ping-pong buffers. `MAMBA_SKIP_DECODE_LOCK=1` removes one slot per
request. The speculative verify window is a separate engine buffer.

The launch script therefore computes:

```text
max_mamba_cache_size = MAX_CONCURRENT_REQUESTS × (5 - MAMBA_SKIP_DECODE_LOCK)
```

The default is `10 × 5 = 50`.

## Upgrade procedure

Never point the existing overlay at a new image and hope imports remain
compatible.

1. Resolve the new image digest and installed SGLang commit.
2. Extract the five corresponding image files.
3. Reapply only the upstream DFlash2 delta with a real three-way merge.
4. Check whether the quantized LM-head change is already upstream.
5. Run Python compilation and exact-image import tests.
6. Run a selector unit test with a quantized target LM head.
7. Boot on GB10 and confirm target/draft graph capture.
8. Run `smoke-qwen38-dflash2.sh` and `bench/ndec.py`.
9. Replace the manifest hashes only after all gates pass.

When an official Qwen3.8 aarch64 SGLang image contains both DFlash2 and
quantized selector support, removing the overlay is preferable to carrying it
forward.
