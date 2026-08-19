#!/usr/bin/env python3
"""Two-call delta benchmark for net decode throughput.

The short and long calls use the same prompt. Subtracting their time and token
counts reduces TTFT/prefill distortion. Compare profiles only in the same boot
window; DGX Spark power and thermal state can move code results materially.
"""

import argparse
import json
import os
import statistics
import time
import urllib.error
import urllib.request


def call(api_base, model, prompt, max_tokens):
    body = {
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.0,
        "max_tokens": max_tokens,
        "chat_template_kwargs": {"enable_thinking": False},
    }
    req = urllib.request.Request(
        api_base.rstrip("/") + "/chat/completions",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"},
    )
    started = time.perf_counter()
    try:
        with urllib.request.urlopen(req, timeout=900) as response:
            result = json.load(response)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode(errors="replace")[:1000]
        raise RuntimeError(f"HTTP {exc.code}: {detail}") from exc
    return time.perf_counter() - started, result["usage"]["completion_tokens"]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--api-base", default=os.getenv("API_BASE", "http://127.0.0.1:8888/v1"))
    parser.add_argument("--model", default=os.getenv("MODEL", "qwen3.8-27b-sglang"))
    parser.add_argument("--runs", type=int, default=int(os.getenv("RUNS", "3")))
    args = parser.parse_args()
    if args.runs < 1:
        parser.error("--runs must be at least 1")

    call(args.api_base, args.model, "Reply with OK.", 16)
    probes = [
        (
            "code",
            "Write a Python class LRUCache with O(1) get and put using OrderedDict, plus a small test.",
        ),
        (
            "essay",
            "Write a detailed technical essay on the history of computing, from Babbage to GPUs.",
        ),
    ]

    for name, prompt in probes:
        rates = []
        for run in range(1, args.runs + 1):
            short_seconds, short_tokens = call(args.api_base, args.model, prompt, 60)
            long_seconds, long_tokens = call(args.api_base, args.model, prompt, 600)
            delta_seconds = long_seconds - short_seconds
            delta_tokens = long_tokens - short_tokens
            if delta_seconds <= 0 or delta_tokens <= 0:
                raise RuntimeError(
                    f"invalid delta for {name}: tokens={delta_tokens}, seconds={delta_seconds:.3f}"
                )
            rate = delta_tokens / delta_seconds
            rates.append(rate)
            print(
                f"{name:5s} run {run}: {rate:6.2f} tok/s "
                f"(short={short_tokens}/{short_seconds:.2f}s, long={long_tokens}/{long_seconds:.2f}s)"
            )
        print(
            f"{name:5s} median: {statistics.median(rates):.2f} tok/s "
            f"(range {min(rates):.2f}-{max(rates):.2f}, n={len(rates)})"
        )


if __name__ == "__main__":
    main()
