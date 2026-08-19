# Changelog

## 2026-08-19 — Make the MiaAI-Lab base credit prominent

- Added a top-of-README attribution identifying
  `MiaAI-Lab/Qwen3.8-27B-SGLang-DGX-Spark` as this repository's primary base.
- Expanded `CREDITS.md` with a concrete inherited-versus-added contribution
  breakdown and added a root `NOTICE.md` for durable attribution.

## 2026-08-19 — Initial public recipe

- Published the validated one-DGX-Spark Qwen3.8-27B NVFP4 + DFlash2 profile.
- Pinned the exact SGLang image, target checkpoint, and DFlash2 draft revision.
- Added the five-file, read-only SGLang overlay with provenance and SHA-256
  verification.
- Added start, stop, status, logs, smoke, benchmark, and CPU-only CI scripts.
- Recorded live correctness gates and same-boot performance in `AUDIT.md`.
- Documented Apache-2.0 overlay lineage separately from the MIT recipe files.
