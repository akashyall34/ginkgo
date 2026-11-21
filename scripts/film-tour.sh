#!/usr/bin/env bash
# Runs one shot of the demo video's app half on the iPhone, at a filming pace.
#   scripts/film-tour.sh chain|proof|contrast|verify
# Start the screen recording first (QuickTime: File > New Movie Recording > pick the iPhone),
# then run this. The shot's timing (scenes and taps) is saved to build/tour/<shot>.txt for editing.
# Options (environment): DEVICE_ID (default: the first connected iPhone), TOUR_DARK=1,
#   TOUR_WALK_MAX (s, default 90), TOUR_AIM_SECONDS (default 3), TOUR_AR_SECONDS (default 10),
#   SIMULATOR=1 to rehearse on the simulator (every shot except chain).
set -euo pipefail
cd "$(dirname "$0")/.."

SHOT="${1:-}"
case "$SHOT" in
  chain) TEST=testChain ;;
  proof) TEST=testProof ;;
  contrast) TEST=testContrast ;;
  verify) TEST=testVerify ;;
  *) echo "Usage: scripts/film-tour.sh chain|proof|contrast|verify"; exit 2 ;;
esac

if [ "${SIMULATOR:-}" = "1" ]; then
  DEST="platform=iOS Simulator,name=${SIMULATOR_NAME:-iPhone 17}"
else
  if [ -z "${DEVICE_ID:-}" ]; then
    DEVICE_ID=$(xcrun xctrace list devices 2>/dev/null | grep -v Simulator | grep -E "iPhone.*\(([0-9A-F-]{25})\)" \
      | head -1 | sed -E 's/.*\(([0-9A-F-]{25})\).*/\1/')
  fi
  if [ -z "${DEVICE_ID:-}" ]; then echo "No iPhone connected. Plug it in and unlock it."; exit 1; fi
  DEST="id=$DEVICE_ID"
fi

mkdir -p build/tour
xcodegen generate --quiet
LOG="build/tour/$SHOT.log"
echo "Filming '$SHOT' on $DEST ..."
set +e
TEST_RUNNER_GINKGO_TOUR=1 \
TEST_RUNNER_TOUR_DARK="${TOUR_DARK:-0}" \
TEST_RUNNER_TOUR_WALK_MAX="${TOUR_WALK_MAX:-90}" \
TEST_RUNNER_TOUR_AIM_SECONDS="${TOUR_AIM_SECONDS:-3}" \
TEST_RUNNER_TOUR_AR_SECONDS="${TOUR_AR_SECONDS:-10}" \
xcodebuild test -project Ginkgo.xcodeproj -scheme Ginkgo -destination "$DEST" \
  -only-testing:"GinkgoUITests/DemoTourUITests/$TEST" -allowProvisioningUpdates > "$LOG" 2>&1
STATUS=$?
set -e
grep -E "^TOUR " "$LOG" > "build/tour/$SHOT.txt" || true
grep -E "error:|failed|skipped|TEST (SUCCEEDED|FAILED)" "$LOG" | tail -6
if [ "$(wc -l < "build/tour/$SHOT.txt")" -eq 0 ]; then
  echo "No shot was filmed (skipped or never started). Full log: $LOG"; exit 1
fi
echo "Timing: build/tour/$SHOT.txt"
cat "build/tour/$SHOT.txt"
exit $STATUS
