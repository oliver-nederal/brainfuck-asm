#!/usr/bin/env python3
"""Correctness and performance tests for the brainfuck executable."""

import argparse
import hashlib
import statistics
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Workload:
    name: str
    source: str | Path
    expected_output: bytes | None = None
    input_data: bytes = b""
    expected_output_length: int | None = None
    expected_output_sha256: str | None = None


REPOSITORY_ROOT = Path(__file__).resolve().parent.parent


WORKLOADS = (
    Workload("single instruction", "+.", b"\x01"),
    Workload("loop arithmetic", "++++++++++[>++++++++++<-]>+.", b"e"),
    Workload(
        "hello world",
        "++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>."
        ">---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++.",
        b"Hello World!\n",
    ),
    Workload(
        "input echo",
        ",.,.,.,.,.,.,.,.,.",
        b"Brainfuck",
        input_data=b"Brainfuck",
    ),
    Workload(
        "input arithmetic",
        ",>,<[->+<]>+.",
        b"\x09",
        input_data=b"\x05\x03",
    ),
    Workload(
        "mandelbrot",
        REPOSITORY_ROOT / "mandelbrot.bf",
        expected_output_length=6240,
        expected_output_sha256="83a0aac65090b3b5e85c22337afac39d8ac17bfd88675f044b33bd55ca0c351b",
    ),
    Workload(
        "large compressed run",
        "+" * 200_000,
        b"",
    ),
)


def run_once(
    binary: Path, source_path: Path, input_data: bytes = b""
) -> tuple[float, bytes]:
    start = time.perf_counter_ns()
    result = subprocess.run(
        [str(binary), str(source_path)],
        input=input_data,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    elapsed_ms = (time.perf_counter_ns() - start) / 1_000_000
    if result.returncode != 0:
        error = result.stderr.decode(errors="replace").strip()
        raise RuntimeError(
            f"{binary} exited with status {result.returncode}"
            + (f": {error}" if error else "")
        )
    return elapsed_ms, result.stdout


def format_output(output: bytes) -> str:
    if not output:
        return "(none)"
    if len(output) > 120:
        digest = hashlib.sha256(output).hexdigest()
        return f"<{len(output)} bytes, sha256={digest}>"
    if all(32 <= byte < 127 or byte in (9, 10, 13) for byte in output):
        return repr(output.decode())
    return output.hex()


def benchmark(binary: Path, runs: int, warmup: int) -> int:
    failures = 0
    print(f"Brainfuck performance suite ({runs} measured runs, {warmup} warmups)")
    print(f"Binary: {binary}")
    print()
    print(
        f"{'Workload':<22} {'Source':>10} {'Output':>18} "
        f"{'Median':>10} {'Min':>10} {'Max':>10} {'Throughput':>14}"
    )
    print("-" * 100)

    with tempfile.TemporaryDirectory(prefix="brainfuck-benchmark-") as directory:
        for workload in WORKLOADS:
            if isinstance(workload.source, Path):
                source_path = workload.source
            else:
                source_path = Path(directory) / f"{workload.name.replace(' ', '_')}.bf"
                source_path.write_text(workload.source, encoding="ascii")

            try:
                for _ in range(warmup):
                    run_once(binary, source_path, workload.input_data)
                first_sample, output = run_once(binary, source_path, workload.input_data)
                if workload.expected_output is not None and output != workload.expected_output:
                    raise AssertionError(
                        f"expected {format_output(workload.expected_output)}, "
                        f"got {format_output(output)}"
                    )
                if (
                    workload.expected_output_length is not None
                    and len(output) != workload.expected_output_length
                ):
                    raise AssertionError(
                        f"expected {workload.expected_output_length} output bytes, "
                        f"got {len(output)}"
                    )
                if workload.expected_output_sha256 is not None:
                    digest = hashlib.sha256(output).hexdigest()
                    if digest != workload.expected_output_sha256:
                        raise AssertionError(
                            f"expected SHA-256 {workload.expected_output_sha256}, "
                            f"got {digest}"
                        )

                samples = [first_sample]
                samples.extend(
                    run_once(binary, source_path, workload.input_data)[0]
                    for _ in range(runs - 1)
                )
            except (AssertionError, OSError, RuntimeError) as error:
                failures += 1
                print(f"{workload.name:<22} FAILED: {error}", file=sys.stderr)
                continue

            median = statistics.median(samples)
            minimum = min(samples)
            maximum = max(samples)
            source_size = source_path.stat().st_size
            source_kib = source_size / 1024
            throughput = source_kib / (median / 1000) if median else float("inf")
            print(
                f"{workload.name:<22} {source_size:>9,} B "
                f"{format_output(output):>18} {median:>8.2f} ms "
                f"{minimum:>8.2f} ms {maximum:>8.2f} ms "
                f"{throughput:>10.1f} KiB/s"
            )

    print()
    if failures:
        print(f"{failures} workload(s) failed.", file=sys.stderr)
        return 1
    print("All correctness checks passed.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run correctness checks and benchmark the brainfuck executable."
    )
    parser.add_argument("--binary", type=Path, default=Path("./brainfuck"))
    parser.add_argument("--runs", type=int, default=5)
    parser.add_argument("--warmup", type=int, default=1)
    args = parser.parse_args()
    if args.runs < 1 or args.warmup < 0:
        parser.error("--runs must be positive and --warmup cannot be negative")
    if not args.binary.is_file():
        parser.error(f"binary does not exist: {args.binary}")
    return benchmark(args.binary.resolve(), args.runs, args.warmup)


if __name__ == "__main__":
    raise SystemExit(main())
