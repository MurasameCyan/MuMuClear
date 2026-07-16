"""Binary-patch ENABLE_TASKBAR_NAVBAR_UNIFICATION init to false in DEX 038.

Keeps file size and header version identical (smali reassembly produced DEX 041
which ART rejects: Header size is 112 but 120 was expected).
"""
from __future__ import annotations

import hashlib
import struct
import zlib
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SRC_APK = ROOT / "build" / "Lawnchair_app.lawnchair_signed.pre_layoutter_patch.apk"
OUT_UNSIGNED = ROOT / "build" / "dex_patch" / "Lawnchair_binpatch_unsigned.apk"
OUT_ALIGNED = ROOT / "build" / "dex_patch" / "Lawnchair_binpatch_aligned.apk"
OUT_SIGNED = ROOT / "Lawnchair_app.lawnchair_signed.apk"
PATCHED_DEX = ROOT / "build" / "dex_patch" / "classes_binpatched.dex"

# FeatureFlags.<clinit>: const/4 v1, 0x1 just before sput-boolean ENABLE_TASKBAR_NAVBAR_UNIFICATION
CONST4_OFF = 0x2554EA
EXPECTED = bytes.fromhex("12116a01ba22")  # const/4 v1,1 ; sput-boolean v1, field@22ba
REPLACEMENT_FIRST = bytes.fromhex("1201")  # const/4 v1, 0


def fix_dex_checksums(dex: bytearray) -> None:
    # signature: sha-1 of bytes[32:]
    sig = hashlib.sha1(dex[32:]).digest()
    dex[12:32] = sig
    # checksum: adler32 of bytes[12:]
    csum = zlib.adler32(dex[12:]) & 0xFFFFFFFF
    struct.pack_into("<I", dex, 8, csum)


def main() -> None:
    with zipfile.ZipFile(SRC_APK, "r") as zin:
        dex = bytearray(zin.read("classes.dex"))

    window = bytes(dex[CONST4_OFF : CONST4_OFF + 6])
    if window != EXPECTED:
        raise SystemExit(f"unexpected bytes at {CONST4_OFF:#x}: {window.hex()} != {EXPECTED.hex()}")

    dex[CONST4_OFF : CONST4_OFF + 2] = REPLACEMENT_FIRST
    if bytes(dex[CONST4_OFF : CONST4_OFF + 6]) != bytes.fromhex("12016a01ba22"):
        raise SystemExit("patch verification failed")

    fix_dex_checksums(dex)
    PATCHED_DEX.write_bytes(dex)
    print(f"patched dex written: {PATCHED_DEX} ({len(dex)} bytes)")
    print(f"const/4 site: {bytes(dex[CONST4_OFF:CONST4_OFF+6]).hex()}")

    # rebuild APK without META-INF
    with zipfile.ZipFile(SRC_APK, "r") as zin, zipfile.ZipFile(OUT_UNSIGNED, "w") as zout:
        for item in zin.infolist():
            if item.filename.startswith("META-INF/"):
                continue
            data = zin.read(item.filename)
            if item.filename == "classes.dex":
                data = bytes(dex)
            if item.compress_type == zipfile.ZIP_STORED:
                zout.writestr(item, data)
            else:
                zi = zipfile.ZipInfo(filename=item.filename, date_time=item.date_time)
                zi.compress_type = zipfile.ZIP_DEFLATED
                zi.external_attr = item.external_attr
                zout.writestr(zi, data)

    print(f"unsigned apk: {OUT_UNSIGNED} ({OUT_UNSIGNED.stat().st_size})")


if __name__ == "__main__":
    main()
