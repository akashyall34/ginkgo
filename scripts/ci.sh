#!/usr/bin/env bash
# Runs every check for Ginkgo. Exits non-zero on the first failure.
set -euo pipefail
cd "$(dirname "$0")/.."
SIMULATOR="${SIMULATOR:-iPhone 17}"
mkdir -p build

echo "== 1. Generated models match the schema"
TMP=$(mktemp -d)
quicktype -s schema "schema/ginkgo.schema.json#/definitions/" \
  -l swift --struct-or-class struct --access-level internal -o "$TMP/GinkgoModels.swift"
diff -q "$TMP/GinkgoModels.swift" Ginkgo/Models/GinkgoModels.swift
echo "up to date"

echo "== 2. Lint (strict: any warning fails)"
swiftlint lint --quiet --strict
echo "clean"

echo "== 3. Build (warnings are errors) and run unit + UI tests"
xcodegen generate --quiet
rm -rf build/ci.xcresult
set +e
xcodebuild test -project Ginkgo.xcodeproj -scheme Ginkgo \
  -destination "platform=iOS Simulator,name=$SIMULATOR" \
  -resultBundlePath build/ci.xcresult > build/ci.log 2>&1
STATUS=$?
set -e
grep -E "error:|Test Case .*failed|Executed [0-9]+ tests.*seconds$|TEST (SUCCEEDED|FAILED)" build/ci.log | tail -12
if [ $STATUS -ne 0 ]; then echo "CI failed. Full log: build/ci.log"; exit $STATUS; fi

echo "== 4. Test coverage of logic files"
python3 scripts/coverage-gate.py build/ci.xcresult

echo "CI passed."
