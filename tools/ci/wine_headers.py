#!/usr/bin/env python3
"""Generate every concrete Wine header target declared by the configured build."""

import argparse
import os
from pathlib import Path
import subprocess


def header_targets(makefile_text: str) -> list[str]:
    """Return concrete include/*.h targets that Wine's configured Makefile can build."""
    targets: set[str] = set()

    for raw in makefile_text.splitlines():
        # Recipe lines, comments and variable assignments are not target rules.
        if not raw or raw[0].isspace() or raw.startswith("#") or ":" not in raw:
            continue

        lhs = raw.split(":", 1)[0]
        if "=" in lhs:
            continue

        for token in lhs.split():
            if (
                token.startswith("include/")
                and token.endswith(".h")
                and "$" not in token
                and "%" not in token
            ):
                targets.add(token)

    if not targets:
        raise ValueError("Configured Wine Makefile declares no concrete include/*.h targets")
    return sorted(targets)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root", type=Path, default=Path(__file__).resolve().parents[2]
    )
    args = parser.parse_args()

    root = args.root.resolve()
    source = root / "wine"
    build = source / "build-macos"
    makefile = build / "Makefile"

    if not makefile.is_file():
        raise SystemExit("Configure Wine build-macos before generating headers")

    targets = header_targets(makefile.read_text(errors="replace"))

    env = os.environ.copy()
    env["PATH"] = (
        str(root / "toolchains/llvm-mingw-20260421-ucrt-macos-universal/bin")
        + ":/opt/homebrew/opt/bison/bin:"
        + env["PATH"]
    )

    print(
        f"Generating {len(targets)} concrete Wine header targets from configured Makefile",
        flush=True,
    )
    subprocess.run(
        ["make", "-C", str(build), "-j3", *targets],
        check=True,
        env=env,
    )

    missing = [target for target in targets if not (build / target).is_file()]
    if missing:
        raise SystemExit("Header generation incomplete: " + ", ".join(missing))

    print(f"Verified {len(targets)} generated Wine headers", flush=True)


if __name__ == "__main__":
    main()
