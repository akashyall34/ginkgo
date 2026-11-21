# Sag check: our numbers against the Sagulator

Ginkgo's sag check (`Packages/GinkgoCore/Sources/GinkgoCore/Sag.swift`) uses the standard formula for a
simply supported board under an even load: δ = 5·w·L⁴ / (384·E·I), with I = b·t³ / 12 and w = load × 9.81 / L.
A seat or shelf passes when δ ≤ L / 600 (the spec's "0.02 in per foot of span", which is also the Sagulator's target).
Design loads: seat 100 kg, shelf 30 kg. Stiffness values, sources and check dates live in one table,
`MaterialCatalog` (`Materials.swift`).

## Stiffness values and sources

| Material | E used (N/mm²) | Source | Cross-check |
|---|---|---|---|
| Solid wood | 9,000 | USDA Forest Products Laboratory, *Wood Handbook*, FPL-GTR-282 (2021), ch. 5 | Sagulator, Eastern white pine, 2026-11-21 |
| Plywood | 7,000 | USDA Forest Products Laboratory, *Wood Handbook*, FPL-GTR-282 (2021) | Sagulator, fir plywood, 2026-11-21 |
| Particleboard/MDF | 2,500 | ANSI A208.1-2022 / A208.2-2022 MOE grades | Sagulator, M-2 particleboard, 2026-11-21 |
| Plastic | none | No single stiffness for hollow molded parts | Rule: never a seat or shelf (trust audit, 2026-11-21) |
| Cardboard | none | Corrugated board's stiffness depends on its flutes, not one constant | Rule: never a seat or shelf (trust audit, 2026-11-21) |

Plastic and cardboard have **no stiffness number at all**. A seat or shelf made of them is rejected with
"isn't load-bearing", and no sag figure is computed or shown.

## The five cases, run on the Sagulator (woodbin.com) on 2026-11-21

Settings: Floating (not attached), total load in kg, uniform load, mm, no edging strip.

| # | Case | Span × depth × thickness (mm) | Load | Ginkgo δ | Sagulator δ | Difference | Verdict |
|---|---|---|---|---|---|---|---|
| 1 | Sample bench seat | 360 × 300 × 19, Eastern white pine | 100 kg | 0.386 mm | 0.41 mm | ours 6% lower | both pass |
| 2 | Bigger seat | 414 × 392 × 19, Eastern white pine | 100 kg | 0.449 mm | 0.47 mm | ours 4% lower | both pass |
| 3 | Fallback seat | 414 × 362 × 19, Eastern white pine | 100 kg | 0.487 mm | 0.51 mm | ours 5% lower | both pass |
| 4 | Long plywood shelf | 900 × 280 × 18, fir plywood | 30 kg | 2.933 mm | 2.48 mm | ours 18% higher | both sag |
| 5 | Particleboard shelf | 800 × 300 × 16, M-2 particleboard | 30 kg | 7.664 mm | 8.68 mm | ours 12% lower | both sag |

## Conclusion

- **The verdict matches in all 5 cases.** Every difference is within 18%, inside the 25% bar we set.
- Our solid wood value (9,000) is slightly stiffer than the Sagulator's Eastern white pine: we predict about 5%
  less sag. Our particleboard value predicts 12% less sag than M-2 grade. Our plywood value predicts 18% more.
  So our values are **close, not conservative**, for wood and particleboard. The 1/600 limit and the 25% bar
  leave room for that, and the margins in real plans are much larger (a typical seat uses 0.4–0.5 of 0.6–0.7 mm).
- The Sagulator reports initial sag only (its note 2: wood sags about 50% more over time). So does Ginkgo.
- Each Ginkgo value is pinned by a known-answer test in `SagTests.swift`, and `scripts/prove-tests-core.sh`
  shows the tests fail if the 1/600 limit is changed.
