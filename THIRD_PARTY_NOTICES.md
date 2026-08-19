# Third-party notices

## SGLang-derived overlay

The following files are derived from the SGLang project and include a
three-way merge of SGLang DFlash2 changes:

- `overlay/sglang/kernels/ops/speculative/dflash.py`
- `overlay/sglang/srt/model_executor/model_runner_components/spec_aux_hidden_state.py`
- `overlay/sglang/srt/models/dflash.py`
- `overlay/sglang/srt/speculative/dflash_utils.py`
- `overlay/sglang/srt/speculative/dflash_worker_v2.py`

SGLang is licensed under Apache License 2.0. A copy is provided at
`LICENSES/Apache-2.0.txt`. Exact source commits and checksums are recorded in
`overlay/MANIFEST.md`.

## External artifacts

This repository does not redistribute model weights, the SGLang container
image, NVIDIA software, FlashInfer, Triton, or ModelOpt. The launch script
downloads or uses those separate artifacts, each under its upstream terms.
