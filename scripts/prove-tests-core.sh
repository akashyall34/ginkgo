#!/usr/bin/env bash
# Proves the GinkgoCore tests catch bugs: plants six known bugs ("mutants"), one at a time, on the lines
# marked `// MUTANT:<name>`, and expects the tests to fail for each. The original file is always restored,
# even on Ctrl-C. Runs on Linux and macOS (bash 3.2). Optional: GINKGO_BUILD_DIR as in ci-core.sh.
set -uo pipefail
cd "$(dirname "$0")/.."
PKG=Packages/GinkgoCore
SRC=$PKG/Sources
SWIFT_ARGS="--package-path $PKG"
if [ -n "${GINKGO_BUILD_DIR:-}" ]; then SWIFT_ARGS="$SWIFT_ARGS --scratch-path $GINKGO_BUILD_DIR"; fi
MUTANTS="margin fit-compare overlap sag-limit damaged accept"
LOG=$(mktemp)
BACKUP=""
TARGET=""

restore() {
  if [ -n "$BACKUP" ] && [ -n "$TARGET" ]; then cp "$BACKUP" "$TARGET"; fi
  BACKUP=""
  TARGET=""
}
trap 'restore; rm -f "$LOG"' EXIT
trap 'restore; echo "Interrupted: original restored."; exit 130' INT TERM

substitution() {
  case "$1" in
    margin) echo 's/8\.0/0.0/' ;;
    fit-compare) echo 's/<=/</' ;;
    overlap) echo 's/</<=/' ;;
    sag-limit) echo 's/600/300/' ;;
    damaged) echo 's/if part\.damaged/if false \&\& part.damaged/' ;;
    accept) echo 's/\bif\s+/if false \&\& /' ;;
  esac
}

checksum() {
  find "$SRC" -name '*.swift' -type f | sort | while IFS= read -r FILE; do cksum "$FILE"; done | cksum
}

run_tests() {
  # shellcheck disable=SC2086 # SWIFT_ARGS is split into words on purpose
  swift test $SWIFT_ARGS > "$LOG" 2>&1
}

echo "== Baseline: the unchanged code must pass, or every mutant would look caught"
if ! run_tests; then
  grep -E "error:|failed" "$LOG" | head -5
  echo "Baseline tests fail. Fix them before proving anything."
  exit 1
fi
BEFORE=$(checksum)

TOTAL=0
CAUGHT=0
for NAME in $MUTANTS; do
  TOTAL=$((TOTAL + 1))
  MATCHES=$(grep -rn "// MUTANT:$NAME\$" "$SRC" || true)
  COUNT=$(printf "%s" "$MATCHES" | grep -c . || true)
  if [ "$COUNT" -ne 1 ]; then
    echo "SURVIVED: $NAME (marker found $COUNT times; it must be on exactly one line)"
    continue
  fi
  TARGET=${MATCHES%%:*}
  BACKUP=$(mktemp)
  cp "$TARGET" "$BACKUP"
  perl -pi -e "$(substitution "$NAME") if /\\/\\/ MUTANT:$NAME\$/" "$TARGET"
  if cmp -s "$BACKUP" "$TARGET"; then
    echo "SURVIVED: $NAME (the substitution changed nothing)"
    restore
    continue
  fi
  LINE=$(grep "// MUTANT:$NAME\$" "$TARGET" | sed 's/^ *//')
  if run_tests; then
    echo "SURVIVED: $NAME   $LINE"
  else
    CAUGHT=$((CAUGHT + 1))
    FAILS=$(grep -cE "error: .*(XCTAssert|failed|threw)" "$LOG" || true)
    echo "caught:   $NAME   ($FAILS failing checks)   $LINE"
  fi
  restore
done

if [ "$(checksum)" != "$BEFORE" ]; then
  echo "ERROR: the sources differ from before the run."
  exit 1
fi
echo "Sources restored (checksums match)."
echo "Mutants caught: $CAUGHT/$TOTAL"
[ "$CAUGHT" -eq "$TOTAL" ]
