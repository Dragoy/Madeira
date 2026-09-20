#!/usr/bin/env python3
from pathlib import Path
import re

root = Path(__file__).resolve().parents[2]
thread = (root / "build/ntdll-unix/thread_ios.c").read_text()

m = re.search(
    r"void\s+abort_process\s*\(\s*int\s+status\s*\)\s*\{(?P<body>.*?)\n\}",
    thread,
    re.S,
)
if not m:
    raise SystemExit("abort_process() not found")

body = m.group("body")
ios_part = body.split("#else", 1)[0]

checks = {
    "iOS abort_process uses the Wine thread/process exit shim":
        "wine_ios_exit( code );" in ios_part,
    "iOS abort_process logs the NTSTATUS to unified logging":
        "abort_process intercepted" in ios_part and "os_log_error" in ios_part,
    "iOS abort_process never calls real _exit":
        not any(line.lstrip().startswith("_exit(") for line in ios_part.splitlines()),
    "non-iOS upstream _exit behavior remains":
        "#else" in body and "_exit( get_unix_exit_code( status ));" in body,
}

failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(("PASS" if ok else "FAIL") + ": " + name)

if failed:
    raise SystemExit("iOS guest-abort regression checks failed: " + "; ".join(failed))
