<p align="center">
  <img src="brand/ginkgo-logo.png" alt="Ginkgo logo: a ginkgo leaf made of cut panels" width="320">
</p>

<h3 align="center">Measure it with your phone. Get a plan that fits.</h3>

In 2018 Americans generated 12.1 million tons of furniture waste, and 80% of it went to landfill
([EPA, 2018 data](https://www.epa.gov/facts-and-figures-about-materials-waste-and-recycling/durable-goods-product-specific-data)).
Much of it is still good wood. Ginkgo takes a piece of furniture you want to take apart and shows
you what to build from its panels, from measuring to the last screw, using only an iPhone.

## What it does

1. **Scan.** Point the LiDAR at one flat face. Ginkgo measures it, with a ± error on each size.
2. **Parts.** Gemini reads a photo and lists the panels. You confirm each one's material and grain.
3. **Take it apart.** The order things come off, how each part is held, and the tools to use.
4. **Measure each panel.** Lay a panel flat and scan it for width, height, thickness and screw
   holes. No tape needed.
5. **Plan.** A bench, shelf or similar, built only from those panels. Every plan is checked
   before you see it (see below).
6. **Cut.** Cut lines are drawn in AR on the real panel. After cutting, a check scan tells you
   whether each piece is good, needs a trim, or must be recut.
7. **Assemble.** 3D steps, with the screws and brackets worked out from the scanned thickness.

No LiDAR? **My items** has sample pieces, so the whole flow works on any iPhone.

## How the AI is used

**AI suggests, code decides.** The models propose; sizes, fits, strength and stability are
tested Swift code. A plan the validator rejects is never shown. Details: [docs/AI.md](docs/AI.md).

| Task | Runs on | Why |
| --- | --- | --- |
| Read the parts from the photo | Gemini, in the cloud | Needs an image; the on-device model takes none |
| Take-apart order | Gemini, in the cloud | Needs the photo |
| Plan from the measured panels | Apple's on-device model first. Gemini after 3 rejected plans or 60 s | Numbers only: fast, free, works offline |
| Improve this plan | Gemini, when you're back online | Kept only if it passes and reuses more wood |
| No network, no usable plan | Ginkgo's rule-based planner | Always produces a valid plan |

Every plan screen says where it was made, and every run is logged (`routing-log.jsonl`).

## What the validator checks

- **Fit:** each cut fits its panel with an 8 mm margin (3 mm saw kerf + 5 mm measurement
  margin), clear of screw holes and damage.
- **Sag:** seats carry 100 kg and shelves 30 kg with at most span ÷ 600 deflection
  ([docs/sag-check.md](docs/sag-check.md)).
- **Thickness:** a load-bearing panel's thickness must be scanned or measured, never assumed.
- **Material:** guessed wood is rated as particleboard until you confirm it.
- **Grain:** solid wood across the grain, or unchecked, is rated at 2.7% stiffness
  (USDA Wood Handbook FPL-GTR-282, Table 5-1).
- **Stability:** a seat may not overhang its supports by more than 1 mm.
- **Hardware:** steel corner brackets go into panel faces, not end grain. Screws are the longest
  stock #8 that fits the thickness minus 3 mm. Pilot holes follow ANSI B18.6.1.

## Built with

| | |
| --- | --- |
| App | Swift 6, SwiftUI, iOS 17+ (the on-device planner needs iOS 27 with Apple Intelligence) |
| Sensing | ARKit scene depth, plane fitting, Apple Vision, RealityKit, AR Quick Look |
| On-device AI | Apple Foundation Models |
| Cloud AI | Gemini through Firebase AI Logic. No server, and no key in the app. |
| Firebase | AI Logic, App Check, Auth (anonymous, Google), Firestore, Remote Config |
| Core logic | `GinkgoCore`, a Swift package with no UI: packer, validator, sag, planners |
| Models | Generated from [schema/ginkgo.schema.json](schema/ginkgo.schema.json) with quicktype |
| Tooling | Xcode 27.2, XcodeGen, SwiftLint, GitHub Actions |

## Privacy

Everything stays on the phone unless you turn on **Settings → Back up measurements and plans**.
Then only sizes and plans go to Firestore, under your own user. Photos and depth maps never leave
the iPhone. [firestore.rules](firestore.rules) lets each user reach only their own records.

## Build and run

Needs Xcode, [XcodeGen](https://github.com/yonaskolb/XcodeGen),
[SwiftLint](https://github.com/realm/SwiftLint) and [quicktype](https://github.com/glideapps/quicktype).

```sh
xcodegen generate        # creates Ginkgo.xcodeproj from project.yml
scripts/ci.sh --quick    # unit tests only, a few minutes
scripts/ci.sh            # everything: schema, lint, build, unit + UI tests, coverage gate
```

AI and backup need your own Firebase project. Add its `GoogleService-Info.plist` (not
committed) next to `project.yml`, then in the console:

1. **Authentication:** turn on Anonymous and Google.
2. **Firestore:** create a database and publish [firestore.rules](firestore.rules).
3. **Remote Config (optional):** `validator_margin_mm`, `validator_sag_span_divisor`,
   `validator_seat_load_kg`, `validator_shelf_load_kg`, `gemini_models`. Limits can only get
   stricter than the built-in values, and model names must start with `gemini-`.

## Tests

- 819 unit tests and 45 UI tests. The live-network tests and the full UI audit run only on request.
- Every logic file must have at least 85% coverage, or CI fails.
- `scripts/prove-tests-core.sh` plants 8 bugs in the validator and checks the tests catch each.
- A UI accessibility audit covers every screen in light and dark mode at the largest text size.
- `scripts/check-live-ai.sh` makes one real Gemini call and one real Firestore backup.

## New for #BuildHybridAI (work after Nov 21)

- **Hybrid AI:** on-device planning first, with cloud fallback, routing rules and a log;
  "Improve this plan"; Gemini-written take-apart steps.
- **No tape:** thickness scanned from LiDAR, a flat-panel scan, and a validator that refuses
  to trust guessed thickness, material or grain.
- **Cut to assemble:** cut lines in AR, a check scan for each cut piece, tested assembly
  steps and hardware, and the 3D assembly view.
- **A complete app:** opt-in backup, Sign in with Google, Remote Config, sample pieces, an
  impact screen and a first-run guide.
- **Quality:** an accessibility pass on every screen, and CI that runs a quick suite on GitHub
  and the full one locally.

## Credits and disclosures

- In the app: Gemini (Google) and Apple Foundation Models.
- Built with help from Claude Code (Anthropic) for code and tests. Every change goes through the
  test suite, lint and the coverage gate.
- Furniture waste figures: US EPA. Wood stiffness: USDA Forest Products Laboratory.
- Sample pieces are example data, not scans, and the app says so.

Started at USF HackJam 2026. Licensed under [Apache-2.0](LICENSE).
