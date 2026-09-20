#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[2]
signal = (root / "build/ntdll-unix/signal_arm64_ios.c").read_text()
virtual = (root / "build/ntdll-unix/virtual_ios.c").read_text()

checks = {
    "Mach delivery recognizes CHPE emulator stack bounds":
        "EmulatorStackLimit" in signal
        and "EmulatorStackBase" in signal
        and "CHPE-EMULATOR" in signal,
    "Mach delivery has no arbitrary best-effort guest-stack fallback":
        "BEST-EFFORT delivery on guest stack" not in signal,
    "unsafe/out-of-bounds guest SP is redirected to guest-thread abort":
        "ios_mach_redirect_guest_abort" in signal
        and "SP outside native + CHPE emulator stack" in signal,
    "frame underflow redirects rather than declining into host memory":
        "exception frame would leave owned stack" in signal,
    "cross-thread exception frame helper requires CHPE ownership":
        "REFUSE outside owned stacks" in virtual
        and "cpu->EmulatorStackLimit" in virtual
        and "cpu->EmulatorStackBase" in virtual,
    "cross-thread helper does not accept any writable outside-stack address":
        "routine in this port — FEX guest stacks are not Wine views" not in virtual,
}

failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(("PASS" if ok else "FAIL") + ": " + name)

if failed:
    raise SystemExit("Mach stack ownership regression checks failed: " + "; ".join(failed))
