#!/usr/bin/env bash
# CI for Packages/GinkgoCore. Runs on Linux and macOS. Exits non-zero on the first failure.
# Optional: set GINKGO_BUILD_DIR to keep Swift's build folder elsewhere (for example outside a synced
# OneDrive folder on WSL). Written for bash 3.2 too, which is the default bash on macOS.
set -euo pipefail
cd "$(dirname "$0")/.."
PKG=Packages/GinkgoCore
OUT=$PKG/Sources/GinkgoCore/Models/GinkgoModels.swift
SWIFT_ARGS="--package-path $PKG"
if [ -n "${GINKGO_BUILD_DIR:-}" ]; then SWIFT_ARGS="$SWIFT_ARGS --scratch-path $GINKGO_BUILD_DIR"; fi

echo "== C1. Generated models match the schema"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
npx --yes quicktype@26.0.0 -s schema "schema/ginkgo.schema.json#/definitions/" \
  -l swift --struct-or-class struct --access-level public --protocol equatable -o "$TMP/m.swift"
sed 's/Codable, Equatable {/Codable, Equatable, Sendable {/' "$TMP/m.swift" > "$TMP/GinkgoModels.swift"
diff -q "$TMP/GinkgoModels.swift" "$OUT"
echo "up to date"

echo "== C2. Lint (if swiftlint is installed; the Mac CI always lints)"
if command -v swiftlint >/dev/null; then swiftlint lint --quiet --strict $PKG/Sources $PKG/Tests; echo clean
else echo "swiftlint not installed: skipped here, enforced by ci.sh on the Mac"; fi

echo "== C3. Build with warnings as errors"
# shellcheck disable=SC2086 # SWIFT_ARGS is split into words on purpose
swift build $SWIFT_ARGS -Xswiftc -warnings-as-errors 2>&1 | tail -5

echo "== C4. Unit tests with coverage"
# shellcheck disable=SC2086
swift test $SWIFT_ARGS -Xswiftc -warnings-as-errors --enable-code-coverage 2>&1 | tail -15

echo "== C5. Coverage of logic files (>= 85% each)"
# shellcheck disable=SC2086
python3 scripts/core-coverage-gate.py \
  "$(swift test $SWIFT_ARGS -Xswiftc -warnings-as-errors --enable-code-coverage --show-codecov-path)"

echo "CI core passed."
