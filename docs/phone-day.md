# Phone day

Everything that needs a real iPhone, in the order to do it. Pass marks are the plan's own targets; where the plan
sets none, the line says "proposed". Report every run, including failures: a failed run goes in the log like any other.

**Phones:** iPhone 17 Pro (LiDAR and Apple Intelligence) for everything. iPhone 12 Pro Max (LiDAR, no on-device AI)
only as a spare.

**Bring:** calipers, a steel ruler and a tape (to judge Ginkgo, not to feed it), 10 flat panels of different sizes
(including thin and thick ones), a board marked for the AR test, a saw and wood for the cut check, the demo piece,
the Mac and a cable. Results go in `docs/evidence/`.

## 0. Before anything else

| Check | How | Pass |
| --- | --- | --- |
| The app installs and opens on the iPhone 17 Pro | Run from Xcode on the device | Opens to Home, first-run guide shows once |
| Gemini works from a real iPhone | Parts screen on a scan, with the network on | The parts come back "Read by Gemini". If it fails with an App Check error, the simulator-style debug token has to be used on the phone too |
| Anonymous backup and Sign in with Google work on the device | Settings → backup on → Sign in with Google | The Firestore console shows the record and the Authentication user |

## 1. The Nov 25 gate

On-device plans must pass the validator in at least 3 of 5 runs (the plan's own gate). If they don't, the plan says to
simplify the on-device task to template filling.

- Plan the 5 runs on the iPhone 17 Pro, network on, on one piece.
- Record per run: accepted or not, rejected rounds, seconds, which route answered (the badge and `routing-log.jsonl`).
- **Pass:** 3 of 5 accepted on the device.

## 2. Evidence tests (raw logs in `docs/evidence/`)

| Test | What to do | Pass mark | Log |
| --- | --- | --- | --- |
| LiDAR accuracy | 10 panels, each scanned with the flat-panel scan, compared with tape (width, height) and calipers (thickness) | Width, height and thickness each within ±2 mm (target) | `lidar-accuracy.csv`: panel, true mm, measured mm, error, reported ±, pass |
| Planning | 20 runs × 4 pieces (the four samples: nightstand, stool, drawer cart, box), on-device first and cloud for comparison | **Zero unproven plans shown.** Also record the validator pass rate per route and the time | The phone's `routing-log.jsonl`, unedited |
| Offline | 10 runs in airplane mode: measure, parts, plan, validate, 3D | Proposed: all 10 end in a plan the validator accepted | `offline-runs.csv`: run, reached the plan, route, seconds, notes |

To get `routing-log.jsonl` off the phone: in Xcode's device window, select the phone, pick Ginkgo and
download its container; the file is `AppData/Documents/routing-log.jsonl`.

## 3. Cutting

| Test | What to do | Pass mark | Log |
| --- | --- | --- | --- |
| AR cut lines | Mark a board with the plan's cut lines in AR, then measure the marks with the ruler | Within ±3 mm of the planned cut (target) | `ar-lines.csv`: line, planned mm, marked mm, error |
| Cut check | Cut real pieces from the plan, then run the check scan on each | Pieces within ±2 mm (target); the verdict (good, trim, use as is, recut) matches what the caliper says | `cut-check.csv`: piece, planned mm, measured by caliper, verdict from the app |

## 4. The demo piece, start to finish

- Build the demo piece from scan to the last screw, on the phone.
- **Pass:** the hardware list matches what the plan's templates give, every time; every step reads clearly at arm's length.

## 5. Needs the phone to build, not just to test

| Item | Why the phone |
| --- | --- |
| Step 1: finding each panel automatically on the walk-around scan | The code needs real scans to tune against. Not built yet |

## 6. Nov 29

Record the 2:50 video on the iPhone 17 Pro. Open questions that stay open: which piece is the demo, and who records.

## After the day

- Fill the measured numbers into the README: accuracy results, the on-device pass rate, and the figures the video quotes.
- Commit the raw logs unedited.
