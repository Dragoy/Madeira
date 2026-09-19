#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[2]
helper = (root / "app/Madeira/StikJITHelper.swift").read_text()
content = (root / "app/Madeira/ContentView.swift").read_text()
bridge = (root / "app/Madeira/FEXBridge.mm").read_text()
header = (root / "app/Madeira/JITAllocator.h").read_text()

checks = {
    "StikJITHelper has TrollStore non-traced allocation branch":
        "jit_direct_pool_create" in helper and "isDebuggerAttached()" in helper,
    "StikJITHelper does not BRK-detach when TrollStore already detached":
        "TrollStore JIT: debugger already detached" in helper,
    "FEX bridge can allocate without StikDebug BRK":
        "jit_direct_pool_create" in bridge and "jit_is_traced()" in bridge,
    "C JIT API exposes trace state":
        "bool jit_is_traced(void);" in header,
    "C JIT API exposes persistent direct pool":
        "bool jit_direct_pool_create" in header,
    "SIGTRAP fallback is installed when TrollStore detached":
        "void jit_install_trap_handler(void)" in (root / "app/Madeira/JITAllocator.c").read_text()
        and "if (jit_is_traced())" in (root / "app/Madeira/JITAllocator.c").read_text(),
    "JIT badge follows sticky CS_DEBUGGED rather than P_TRACED":
        'entitlementBadge("JIT", granted: jitEnabled)' in content,
}

failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(("PASS" if ok else "FAIL") + ": " + name)

if failed:
    raise SystemExit("TrollStore JIT regression checks failed: " + "; ".join(failed))
