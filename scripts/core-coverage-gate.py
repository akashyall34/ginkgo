#!/usr/bin/env python3
"""Fails CI when any logic file in Packages/GinkgoCore has less test coverage than the minimum.

Reads the llvm-cov JSON that `swift test --enable-code-coverage` writes (Linux and macOS).
Only files under /Sources/GinkgoCore/ are checked. The GinkgoLive command-line tool is network
glue, exercised by the live run, so it isn't checked; keep real logic out of it.
Usage: core-coverage-gate.py <path to the codecov JSON>
"""
import json
import sys

MINIMUM = 85.0
CHECKED_DIR = "/Sources/GinkgoCore/"
EXEMPT_FILES = {
    "GinkgoModels.swift": "generated; checked against the schema",
}

if len(sys.argv) != 2:
    sys.exit("Usage: core-coverage-gate.py <path to the codecov JSON>")

with open(sys.argv[1], encoding="utf-8") as handle:
    report = json.load(handle)

failures, checked = [], []
for entry in report["data"][0]["files"]:
    path = entry["filename"].replace("\\", "/")
    if CHECKED_DIR not in path:
        continue
    name = path.rsplit("/", 1)[-1]
    if name in EXEMPT_FILES:
        continue
    percent = entry["summary"]["lines"]["percent"]
    checked.append((name, percent))
    if percent < MINIMUM:
        failures.append(name)

for name, percent in sorted(checked):
    print(f"  {'FAIL' if percent < MINIMUM else 'ok  '} {percent:5.1f}%  {name}")
if not checked:
    sys.exit("Coverage gate found no logic files to check")
if failures:
    sys.exit(f"Coverage below {MINIMUM:.0f}% in: " + ", ".join(sorted(failures)))
print(f"All {len(checked)} logic files at or above {MINIMUM:.0f}%.")
