#!/usr/bin/env bash
# CPU-only recipe gates. This does not start Docker or test GPU throughput.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

echo "== shell syntax =="
while IFS= read -r file; do
  bash -n "${file}"
  printf 'ok  %s\n' "${file}"
done < <(find . -type f -name '*.sh' -not -path './.git/*' | sort)

echo "== Python compile =="
py_files=()
while IFS= read -r file; do
  py_files+=("${file}")
done < <(find overlay bench -type f -name '*.py' -not -path '*/__pycache__/*' | sort)
python3 -m py_compile "${py_files[@]}"
printf 'ok  py_compile %s files\n' "${#py_files[@]}"

echo "== overlay integrity =="
scripts/verify-overlay-sources.sh

echo "== recipe pins =="
grep -q 'lmsysorg/sglang@sha256:febfb971c7352570fc445c466ebd6ffc9d896024958e544a60f2137fd85856b1' start-qwen38-dflash2.sh
grep -q 'TARGET_REVISION:-554ebba9b5f1b79dc11246341960360e6ef05ef4' start-qwen38-dflash2.sh
grep -q 'DFLASH2_REVISION:-50307d4c4cde6860d4eee73e2547cd786fe8e8a4' start-qwen38-dflash2.sh
grep -q -- '--mamba-radix-cache-strategy extra_buffer' start-qwen38-dflash2.sh
grep -q -- '--speculative-algorithm DFLASH' start-qwen38-dflash2.sh
grep -q -- '--speculative-num-draft-tokens 8' start-qwen38-dflash2.sh
printf 'ok  image/model/runtime pins\n'

echo "== public-tree hygiene =="
[[ ! -e .env ]] || { echo "real .env must not be committed" >&2; exit 1; }
if grep -RInE --exclude-dir=.git --exclude-dir=__pycache__ --exclude='ci-validate.sh' \
  '192[.]168[.]|enrique''murillo|/Users/|/home/[A-Za-z0-9._-]+/|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|gho_[A-Za-z0-9]+|hf_[A-Za-z0-9]{20,}' .; then
  echo "private path, address, key, or token-like value found" >&2
  exit 1
fi
printf 'ok  no deployment-specific paths, private LAN addresses, or token material\n'

echo "CI validate passed (CPU recipe gates only)."
