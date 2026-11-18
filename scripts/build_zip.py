#!/usr/bin/env python3
"""Create a deterministic, directly-installable AddOns/Wortfilter ZIP, after tests."""
import argparse
import re
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
addon = root / "Wortfilter"
toc = addon / "Wortfilter_Camelot.toc"
if not toc.is_file():
    raise SystemExit("Missing addon manifest Wortfilter_Camelot.toc")
manifest = toc.read_text(encoding="utf-8-sig")
version_match = re.search(r"^## Version:\s*(.+?)\s*$", manifest, re.M)
if not version_match:
    raise SystemExit("Version is missing from TOC")
version = version_match.group(1)
entries = [x.strip() for x in manifest.splitlines() if x.strip() and not x.lstrip().startswith("#")]
if not entries or any(not x.endswith(".lua") for x in entries):
    raise SystemExit("TOC must enumerate the Lua files in load order")
expected = {"Wortfilter_Camelot.toc", *entries}
actual = {p.name for p in addon.iterdir() if p.is_file() and p.suffix in (".lua", ".toc")}
if expected != actual:
    raise SystemExit(f"Manifest/file mismatch: missing={expected-actual}; not listed={actual-expected}")
for entry in entries:
    if "/" in entry or "\\" in entry or not (addon / entry).is_file():
        raise SystemExit(f"Missing/unsafe file in TOC: {entry}")

parser = argparse.ArgumentParser()
parser.add_argument("--out", default=f"dist/Wortfilter-v{version}.zip")
args = parser.parse_args()
out = root / args.out
out.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(out, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for name in ["Wortfilter_Camelot.toc", *entries]:
        path = addon / name
        info = zipfile.ZipInfo(f"Wortfilter/{name}", date_time=(2026, 1, 1, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = 0o644 << 16
        archive.writestr(info, path.read_bytes(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
with zipfile.ZipFile(out) as archive:
    assert archive.testzip() is None
    assert set(archive.namelist()) == {"Wortfilter/" + name for name in expected}
print(f"PASS package {out.relative_to(root)}: {len(expected)} files; manifest validated; ZIP CRC OK")
