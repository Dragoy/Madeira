#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[2]
fd = (root / "build/wineserver/fd_ios.c").read_text()

checks = {
    "wineserver wake semaphore is coalesced":
        "__atomic_exchange_n( &ios_srv_wake_pending, 1, __ATOMIC_ACQ_REL )" in fd,
    "server clears wake latch after consuming a wake":
        "__atomic_store_n( &ios_srv_wake_pending, 0, __ATOMIC_RELEASE );" in fd,
    "fallback poll tick is capped at 100Hz":
        "unsigned long long sleep_ns = 10000000ull;" in fd,
    "old 1ms fallback tick is gone":
        "unsigned long long sleep_ns = 1000000ull;" not in fd,
    "raw uncoalesced wake path is gone":
        "if (ios_srv_wake_sem) semaphore_signal( ios_srv_wake_sem );" not in fd,
}

failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(("PASS" if ok else "FAIL") + ": " + name)

if failed:
    raise SystemExit("iOS wineserver wake regression checks failed: " + "; ".join(failed))
