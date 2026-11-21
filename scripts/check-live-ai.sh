#!/usr/bin/env bash
# Makes one real Gemini call through Firebase from the app, on the simulator.
# Separate from ci.sh so Google's server load never fails the normal build.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f GoogleService-Info.plist ] || { echo "Missing GoogleService-Info.plist"; exit 1; }
# The simulator proves itself to App Check with this debug token (registered in the
# Firebase console under App Check → Apps → Manage debug tokens).
# Read only the token's line: sourcing a whole zsh config from bash is unreliable.
if [ -z "${GINKGO_APPCHECK_DEBUG_TOKEN:-}" ]; then
  GINKGO_APPCHECK_DEBUG_TOKEN=$(sed -n 's/^export GINKGO_APPCHECK_DEBUG_TOKEN=//p' ~/.zshrc | tail -1)
fi
[ -n "${GINKGO_APPCHECK_DEBUG_TOKEN:-}" ] || { echo "Missing GINKGO_APPCHECK_DEBUG_TOKEN in ~/.zshrc"; exit 1; }
export TEST_RUNNER_FIRAAppCheckDebugToken="$GINKGO_APPCHECK_DEBUG_TOKEN"
xcodegen generate --quiet
mkdir -p build
set +e
TEST_RUNNER_GINKGO_LIVE_AI=1 xcodebuild test -project Ginkgo.xcodeproj -scheme Ginkgo \
  -destination "platform=iOS Simulator,name=${SIMULATOR:-iPhone 17}" \
  -only-testing:GinkgoTests/LiveAITests > build/live-ai.log 2>&1
STATUS=$?
set -e
grep -E "error:|Test Case .*(passed|failed|skipped)|TEST (SUCCEEDED|FAILED)" build/live-ai.log | cut -c1-300
exit $STATUS
