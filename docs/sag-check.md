# Sag check: our numbers against the Sagulator

Ginkgo's sag check (`Packages/GinkgoCore/Sources/GinkgoCore/Sag.swift`) uses the standard formula for a
simply supported board under an even load: δ = 5·w·L⁴ / (384·E·I), with I = b·t³ / 12 and w = load × 9.81 / L.
A seat or shelf passes when δ ≤ L / 600 (the spec's "0.02 in per foot of span").
Design loads: seat 100 kg, shelf 30 kg. Stiffness values live in one table, `MaterialCatalog` (`Materials.swift`).

## Stiffness values and where they come from

| Material | E used (N/mm²) | Published range | Source |
|---|---|---|---|
| Solid wood | 9,000 | about 8,000–12,000 for common softwoods; hardwoods higher | USDA Wood Handbook (FPL-GTR-282), tables of modulus of elasticity |
| Plywood | 7,000 | about 7,000–10,000 along the face grain | USDA Wood Handbook, plywood chapter |
| Particleboard/MDF | 2,500 | MDF about 2,500–4,000; particleboard about 2,000–3,000 | Manufacturer data sheets |
| Plastic (polypropylene) | 1,200 | about 1,300–1,800 | Polypropylene data sheets; rounded down |
| Cardboard | 200 | not a structural material | Deliberately low, so cardboard never passes as a seat or shelf |

Every value is at or below the low end of its range, so the check is conservative: when in doubt it says "sags".

## The five cases (fill in the Sagulator column)

Open the Sagulator (woodbin.com/calcs/sagulator), choose the material closest to ours, enter the same
span, depth, thickness and load, and write its deflection here. The Sagulator's load box takes pounds and
inches; the conversions are given.

| # | Case | Span × depth × thickness | Load | Ginkgo δ | Limit | Ginkgo says | Sagulator δ | Difference |
|---|---|---|---|---|---|---|---|---|
| 1 | Sample bench seat, solid wood | 360 × 300 × 19 mm (14.2 × 11.8 × 0.75 in) | 100 kg (220 lb) | 0.386 mm | 0.600 mm | passes | | |
| 2 | Bigger seat, solid wood | 414 × 392 × 19 mm (16.3 × 15.4 × 0.75 in) | 100 kg (220 lb) | 0.449 mm | 0.690 mm | passes | | |
| 3 | Fallback seat, solid wood | 414 × 362 × 19 mm (16.3 × 14.3 × 0.75 in) | 100 kg (220 lb) | 0.487 mm | 0.690 mm | passes | | |
| 4 | Long plywood shelf | 900 × 280 × 18 mm (35.4 × 11.0 × 0.71 in) | 30 kg (66 lb) | 2.933 mm | 1.500 mm | sags | | |
| 5 | Particleboard shelf | 800 × 300 × 16 mm (31.5 × 11.8 × 0.63 in) | 30 kg (66 lb) | 7.664 mm | 1.333 mm | sags | | |

Each Ginkgo value is pinned by a known-answer test in `SagTests.swift`, and `scripts/prove-tests-core.sh`
shows the tests fail if the 1/600 limit is changed.

## Conclusion (fill in after the check)

- If the Sagulator's values are within about 25% of ours (it uses species-specific E values), our check is
  confirmed and conservative.
- If any case differs by more than 25%, change that E value in `MaterialCatalog`, update the known answers in
  `SagTests.swift`, and run `scripts/ci-core.sh` and `scripts/prove-tests-core.sh` again.
