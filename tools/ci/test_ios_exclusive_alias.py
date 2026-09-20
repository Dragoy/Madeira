#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[2]
signal = (root / "build/ntdll-unix/signal_arm64_ios.c").read_text()

checks = {
    "aligned JIT STLXR is recognized as an alias permission fault":
        "[alias-excl] ml764" in signal and "alias_exclusive_store" in signal,
    "JIT alias STLXR reconstructs the proven LDAXR+ADD/SUB old value":
        "ios_alias_excl_recover_expected" in signal
        and "fault_pc - 8" in signal
        and "ld_rt != st_rt" in signal,
    "JIT alias STLXR uses a real atomic compare-exchange":
        "ios_alias_excl_cmpxchg" in signal
        and "__atomic_compare_exchange_n" in signal,
    "unknown alias-exclusive sequences are refused rather than guessed":
        "REFUSE unknown STLXR sequence" in signal,
    "legacy unaligned exclusive monitor remains for non-alias faults":
        "UNALIGNED-EXCL rev=ml431" in signal
        and "IOS_EXCL_MON_SLOTS" in signal,
    "unsafe Mach stack abort uses Darwin state macros on the pointed-to state":
        "__darwin_arm_thread_state64_set_sp( *state, safe_sp )" in signal
        and "__darwin_arm_thread_state64_set_pc_fptr( *state, (void *)abort_thread )" in signal,
}

failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(("PASS" if ok else "FAIL") + ": " + name)

if failed:
    raise SystemExit("iOS exclusive-alias regression checks failed: " + "; ".join(failed))
