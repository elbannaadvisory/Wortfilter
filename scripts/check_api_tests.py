#!/usr/bin/env python3
"""Prevent undocumented new public APIs from landing without a named regression test."""
from pathlib import Path
import re

files = [Path("Wortfilter/Wortfilter_Core.lua"), Path("Wortfilter/Wortfilter_UI.lua")]
api = set()
for file in files:
    source = file.read_text(encoding="utf-8")
    api.update(re.findall(r"\bfunction\s+WF\.([A-Za-z_][A-Za-z0-9_]*)\s*\(", source))
    api.update(re.findall(r"\bWF\.([A-Za-z_][A-Za-z0-9_]*)\s*=\s*function\s*\(", source))
    api.update(re.findall(r"\bWF\.([A-Za-z_][A-Za-z0-9_]*)\s*=\s*[a-z][A-Za-z0-9_]*\s*(?:\n|$)", source))
    # Named local helpers are exercised indirectly by their public call paths.
regression = Path("tests/regression.lua").read_text(encoding="utf-8")
missing = [f"WF.{name}" for name in sorted(api) if f'case("WF.{name} ' not in regression]
if missing:
    raise SystemExit("Missing named test case(s) for public methods: " + ", ".join(missing))
print(f"API test manifest: {len(api)} public WF methods all have explicit named test cases: " + ", ".join(sorted(api)))
