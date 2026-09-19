#!/usr/bin/env python3
"""Generate Wine's complete declared IDL header set, not a guessed subset."""
import argparse
import os
from pathlib import Path, PurePosixPath
import re
import shlex
import subprocess


def header_targets(makefile_text: str) -> list[str]:
    flattened = re.sub(r'\\\r?\n', ' ', makefile_text)
    match = re.search(r'^SOURCES\s*=\s*(.*)$', flattened, re.MULTILINE)
    if not match:
        raise ValueError('No SOURCES assignment in Wine include/Makefile.in')
    names = shlex.split(match.group(1), comments=True)
    targets = set()
    for name in names:
        path = PurePosixPath(name)
        if path.suffix != '.idl':
            continue
        if path.is_absolute() or '..' in path.parts:
            raise ValueError(f'Unsafe IDL source path: {name}')
        targets.add('include/' + str(path.with_suffix('.h')))
    if not targets:
        raise ValueError('Wine manifest declares no IDL headers')
    return sorted(targets)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[2])
    args = parser.parse_args()
    root = args.root.resolve()
    source = root / 'wine'
    build = source / 'build-macos'
    targets = header_targets((source / 'include/Makefile.in').read_text())
    # Some IDLs intentionally coexist with a checked-in public header.
    targets = [h for h in targets if not (source / h).is_file()]
    if not (build / 'Makefile').is_file():
        raise SystemExit('Configure Wine build-macos before generating IDL headers')
    env = os.environ.copy()
    env['PATH'] = str(root / 'toolchains/llvm-mingw-20260421-ucrt-macos-universal/bin') + ':/opt/homebrew/opt/bison/bin:' + env['PATH']
    print(f'Generating all {len(targets)} declared Wine IDL headers', flush=True)
    subprocess.run(['make', '-C', str(build), '-j3', *targets], check=True, env=env)
    missing = [h for h in targets if not (build / h).is_file()]
    if missing:
        raise SystemExit('Header generation incomplete: ' + ', '.join(missing))
    print(f'Verified {len(targets)} generated headers', flush=True)


if __name__ == '__main__':
    main()
