# DFlash2 overlay manifest

This is a narrow runtime overlay for one exact Qwen3.8 SGLang image. The image
predates upstream DFlash2, while its installed SGLang package contains custom
Qwen3.8 support that cannot safely be replaced wholesale.

## Pins

| Component | Exact pin |
| --- | --- |
| Target image | `lmsysorg/sglang@sha256:febfb971c7352570fc445c466ebd6ffc9d896024958e544a60f2137fd85856b1` |
| Image SGLang build label | `c4271c3fe1262fc2adbd162c33b25de5255251c5` |
| Upstream DFlash2 merge | [`c14312a66420b75ca9a11bf1817c4db1fa26b097`](https://github.com/sgl-project/sglang/commit/c14312a66420b75ca9a11bf1817c4db1fa26b097) / [PR #35371](https://github.com/sgl-project/sglang/pull/35371) |
| Quantized target LM-head change | [`3be1b3271b3618a81cec50f16235f976e1ccb3e6`](https://github.com/sgl-project/sglang/commit/3be1b3271b3618a81cec50f16235f976e1ccb3e6), from [PR #35462](https://github.com/sgl-project/sglang/pull/35462) |
| DFlash reference inspected | `z-lab/dflash@07ebd93db9f472af339b644bb70221ad8428328a` |
| Target checkpoint | `RadixArk/Qwen3.8-27B-NVFP4@554ebba9b5f1b79dc11246341960360e6ef05ef4` |
| Draft checkpoint | `z-lab/Qwen3.8-27B-DFlash2@50307d4c4cde6860d4eee73e2547cd786fe8e8a4` |

## Construction

The upstream DFlash2 PR delta was three-way merged into the matching custom
modules extracted from the pinned image. The quantized-target selector change
was then applied to `srt/models/dflash.py`, allowing the NVFP4 target's ModelOpt
LM head to score DFlash2 selector candidates.

The launch script mounts only these five files, read-only. It does not mutate
the image, Python installation, or checkpoint cache.

## SHA-256

```text
21f11619531f493bbe9f71d465912ca707f2d722991832e446ff65aecb40528c  overlay/sglang/kernels/ops/speculative/dflash.py
0d807ee6a9bac84a7d845f2b5c2d1ce6147e24e4995b0cf92030ac3906af4817  overlay/sglang/srt/model_executor/model_runner_components/spec_aux_hidden_state.py
cd1c56b3cf2776fb94d3a5a2126fdf1295b25b2120f858da9f09983d4a948674  overlay/sglang/srt/models/dflash.py
2682b65a72ecf717f560e7154c64a429addde69841f509570dc5af86bd4a4f92  overlay/sglang/srt/speculative/dflash_utils.py
80a4ebde5e8107231190be309466b54a2a9b3da756b2dcdb13bec31695c701e0  overlay/sglang/srt/speculative/dflash_worker_v2.py
```

Run `scripts/verify-overlay-sources.sh` before serving. Do not use this overlay
with another SGLang image without repeating the merge, import tests, selector
tests, and live GPU validation.
