# Credits

This recipe combines several public efforts. Please preserve upstream credit
when reusing the launch path, overlay, or benchmark numbers.

## MiaAI-Lab

[MiaAI-Lab/Qwen3.8-27B-SGLang-DGX-Spark](https://github.com/MiaAI-Lab/Qwen3.8-27B-SGLang-DGX-Spark)
provided the original DGX Spark Qwen3.8 packaging, GB10 serving defaults,
DSpark/MTP measurements, and documentation lineage.

The structure and operator-facing style of this repository follow
[MiaAI-Lab/DeepSeek-v4-Flash-DSpark-2x-DGX-Spark](https://github.com/MiaAI-Lab/DeepSeek-v4-Flash-DSpark-2x-DGX-Spark).

## DFlash2

[z-lab/dflash](https://github.com/z-lab/dflash) published DFlash: Block
Diffusion for Flash Speculative Decoding and the
[`z-lab/Qwen3.8-27B-DFlash2`](https://huggingface.co/z-lab/Qwen3.8-27B-DFlash2)
draft checkpoint used here.

Zihan Zhang / [@SubSir](https://github.com/SubSir) authored SGLang
[PR #35371](https://github.com/sgl-project/sglang/pull/35371), the upstream
DFlash2 implementation integrated into this overlay.

LING ZHI / [@ryou315](https://github.com/ryou315) authored the quantized target
LM-head selector work in SGLang
[PR #35462](https://github.com/sgl-project/sglang/pull/35462). This recipe pins
the exact integrated commit in `overlay/MANIFEST.md`.

## Models and runtime

- [RadixArk/Qwen3.8-27B-NVFP4](https://huggingface.co/RadixArk/Qwen3.8-27B-NVFP4)
- [Qwen3.8-27B](https://huggingface.co/Qwen/Qwen3.8-27B)
- [SGLang](https://github.com/sgl-project/sglang)
- NVIDIA CUDA, DGX Spark, GB10, FlashInfer, Triton, and ModelOpt

## License notes

Repo-local scripts and documentation are MIT licensed through `LICENSE`.
The five SGLang-derived overlay modules retain their Apache-2.0 lineage; see
`LICENSES/Apache-2.0.txt` and `THIRD_PARTY_NOTICES.md`. Model weights, the base
container image, CUDA components, and other runtime dependencies are separate
artifacts governed by their own licenses and terms.
