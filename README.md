<p align="center">
  <img src="brand/ginkgo-logo.png" alt="Ginkgo logo: a ginkgo leaf made of cut panels" width="320">
</p>

<h3 align="center">Measure it with your phone. Get a plan that fits.</h3>

Americans throw away 12.1 million tons of furniture a year, and 80% of it goes to landfill ([EPA, 2018 data](https://www.epa.gov/facts-and-figures-about-materials-waste-and-recycling/durable-goods-product-specific-data)). Most of it is still good wood. Ginkgo turns a piece of curbside furniture into a build plan that is **proven to fit**:

1. **Scan.** Point an iPhone's LiDAR sensor at the piece. Ginkgo measures it to the centimeter, each dimension with its ± error.
2. **Parts.** AI reads the photo and lists the panels; you confirm them.
3. **Plan.** AI proposes a new piece, such as a bench, built only from those panels.
4. **Prove.** A deterministic validator checks every cut against the real panels, screw holes and saw margins, and checks shelves for sag. Only plans that pass are shown.
5. **See it.** The old piece's parts reassemble into the new one in 3D, then in AR at full size.

**AI suggests, code decides.** The AI drafts; measurement, validation and the sag physics are tested code. If the AI is slow or unavailable, a rule-based planner still produces a valid plan.

Built for USF HackJam 2026.

## Tech

- Swift and SwiftUI, iOS 17+, on an iPhone with LiDAR (12 Pro or later)
- ARKit scene depth, plane fitting, Apple Vision, RealityKit, AR Quick Look
- Gemini through Firebase AI Logic (no server; the key never ships in the app)

## Build

Requires Xcode, [XcodeGen](https://github.com/yonaskolb/XcodeGen), [SwiftLint](https://github.com/realm/SwiftLint) and [quicktype](https://github.com/glideapps/quicktype).

```sh
xcodegen generate     # creates Ginkgo.xcodeproj from project.yml
scripts/ci.sh         # schema check, lint, build, unit + UI tests, coverage gate
```

AI features need your own Firebase project: add its `GoogleService-Info.plist` (not committed) to the project folder.
