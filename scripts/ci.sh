#!/usr/bin/env bash
# Runs every check for Ginkgo. Exits non-zero on the first failure.
#
#   scripts/ci.sh           full run: core package, lint, build, unit + UI tests, coverage. Before every push.
#   scripts/ci.sh --quick   while building: core package, lint, build, unit tests. Skips the slow UI tests
#                           and the app coverage gate (UI tests cover part of it), so it can't replace a full run.
#
# Optional: SIMULATOR picks the simulator; SPM_DIR keeps Swift packages in a folder CI can cache.
set -euo pipefail
cd "$(dirname "$0")/.."
SIMULATOR="${SIMULATOR:-iPhone 17}"
QUICK=0
case "${1:-}" in
  --quick) QUICK=1 ;;
  "") ;;
  *) echo "Usage: scripts/ci.sh [--quick]"; exit 2 ;;
esac
mkdir -p build
START=$SECONDS

echo "== 0+1. GinkgoCore package: models match the schema, lint, build (warnings are errors),"
echo "        unit tests, coverage of at least 85% per logic file"
scripts/ci-core.sh

echo "== 2. Lint (strict: any warning fails)"
swiftlint lint --quiet --strict
echo "clean"

ONLY=()
if [ $QUICK -eq 1 ]; then
  echo "== 3. Build (warnings are errors) and run unit tests (quick: no UI tests)"
  ONLY=(-only-testing:GinkgoTests)
else
  echo "== 3. Build (warnings are errors) and run unit + UI tests"
fi
SPM=()
if [ -n "${SPM_DIR:-}" ]; then SPM=(-clonedSourcePackagesDirPath "$SPM_DIR"); fi
xcodegen generate --quiet
rm -rf build/ci.xcresult
set +e
# The full output goes to build/ci.log; milestones and each test result also print here as they happen,
# so a slow or stuck step is visible (locally and in the GitHub Actions console).
xcodebuild test -project Ginkgo.xcodeproj -scheme Ginkgo \
  -destination "platform=iOS Simulator,name=$SIMULATOR" \
  -parallel-testing-enabled YES -parallel-testing-worker-count "${CI_WORKERS:-3}" \
  ${ONLY[@]+"${ONLY[@]}"} ${SPM[@]+"${SPM[@]}"} \
  -resultBundlePath build/ci.xcresult 2>&1 | tee build/ci.log | grep --line-buffered -E \
  "^Resolve Package Graph|^Fetching from|^Resolved source packages|^Testing started|Test [Cc]ase .*(passed|failed)|error:" \
  | sed -u 's/^/   /'
STATUS=${PIPESTATUS[0]}
set -e
echo "-- $((SECONDS - START)) s so far"
grep -E "error:|Test [Cc]ase .*failed|Executed [0-9]+ tests.*seconds$|TEST (SUCCEEDED|FAILED)" build/ci.log | tail -12
if [ $STATUS -ne 0 ]; then echo "CI failed. Full log: build/ci.log"; exit $STATUS; fi

if [ $QUICK -eq 1 ]; then
  echo "Quick CI passed in $((SECONDS - START)) s. Run scripts/ci.sh (full) before pushing."
  exit 0
fi

echo "== 4. Test coverage of logic files"
python3 scripts/coverage-gate.py build/ci.xcresult

echo "CI passed in $((SECONDS - START)) s."
