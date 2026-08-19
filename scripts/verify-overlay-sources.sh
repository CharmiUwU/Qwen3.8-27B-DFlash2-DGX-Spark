#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

expected=(
  "21f11619531f493bbe9f71d465912ca707f2d722991832e446ff65aecb40528c overlay/sglang/kernels/ops/speculative/dflash.py"
  "0d807ee6a9bac84a7d845f2b5c2d1ce6147e24e4995b0cf92030ac3906af4817 overlay/sglang/srt/model_executor/model_runner_components/spec_aux_hidden_state.py"
  "cd1c56b3cf2776fb94d3a5a2126fdf1295b25b2120f858da9f09983d4a948674 overlay/sglang/srt/models/dflash.py"
  "2682b65a72ecf717f560e7154c64a429addde69841f509570dc5af86bd4a4f92 overlay/sglang/srt/speculative/dflash_utils.py"
  "80a4ebde5e8107231190be309466b54a2a9b3da756b2dcdb13bec31695c701e0 overlay/sglang/srt/speculative/dflash_worker_v2.py"
)

digest() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

for item in "${expected[@]}"; do
  wanted="${item%% *}"
  file="${item#* }"
  [[ -f "${file}" ]] || { echo "missing ${file}" >&2; exit 1; }
  actual="$(digest "${file}")"
  if [[ "${actual}" != "${wanted}" ]]; then
    echo "checksum mismatch: ${file}" >&2
    echo "  expected ${wanted}" >&2
    echo "  actual   ${actual}" >&2
    exit 1
  fi
  printf 'ok  %s\n' "${file}"
done

grep -q 'c14312a66420b75ca9a11bf1817c4db1fa26b097' overlay/MANIFEST.md
grep -q '3be1b3271b3618a81cec50f16235f976e1ccb3e6' overlay/MANIFEST.md
grep -q 'febfb971c7352570fc445c466ebd6ffc9d896024958e544a60f2137fd85856b1' overlay/MANIFEST.md
echo "Overlay provenance and checksums passed."
