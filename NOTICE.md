# Attribution notice

This repository is an extension of
[MiaAI-Lab/Qwen3.8-27B-SGLang-DGX-Spark](https://github.com/MiaAI-Lab/Qwen3.8-27B-SGLang-DGX-Spark),
the primary base recipe.

MiaAI-Lab published the original Qwen3.8 DGX Spark serving scaffold, GB10
configuration and tuning, NVFP4 target path, reasoning/tool setup, DSpark/MTP
alternatives, benchmark fixtures, and documentation lineage used by this work.

The changes introduced here are the DFlash2 speculative-decoding integration,
the quantized-target selector compatibility overlay, exact source/model pins,
live DFlash2 validation, and the shareable operational/CI packaging.

Please preserve this notice, the MiaAI-Lab copyright line in `LICENSE`, and the
full attribution in `CREDITS.md` when redistributing or deriving from this
recipe.
