# How Ginkgo uses AI

**AI suggests, code decides.** Gemini does what AI is good at: seeing parts in a photo and proposing designs.
Everything that must be exact is deterministic Swift with tests: sizes in millimetres, every cut, the sag
physics, stability and the final yes or no. No plan reaches the screen unless the validator accepted it.

## Gemini in the app (Firebase AI Logic; no server, and the key never ships in the app)

1. **Parts reader.** Gemini looks at one photo and lists the parts (top, sides, legs, rails, drawers…), where
   each one is in the photo, its likely material (wood, plywood, particleboard, plastic, cardboard), and whether
   it is damaged, padded or curved. It answers in structured JSON. **Code** then turns the photo boxes into
   millimetres using the LiDAR measurement and flags anything to check: a size guess more than 15% off, a part
   hidden in the photo, padding, curves, damage. Code never invents parts.
2. **Planning agent.** A Gemini agent designs the new piece through function calling. It must call our tools:
   - `check_fit`: our packer adds the 8 mm saw and measurement margin and avoids screw holes;
   - `check_sag`: our beam physics checks seats (100 kg) and shelves (30 kg);
   - `submit_plan`: our validator accepts or rejects the whole plan, with plain-English reasons.

   Gemini reads the results and repairs its own design. In live runs it typically fails a check, fixes it and
   is accepted within 10–20 seconds.
3. **Safety net.** If Gemini is slow (25 s), unreachable or never reaches an accepted plan, a rule-based planner
   builds one that passes the same validator, or honestly says that no safe plan exists.

## More than wood

Ginkgo knows five materials in one tested table (`MaterialCatalog`): solid wood and plywood can be cut;
particleboard/MDF, plastic and cardboard are reused whole. The same table sets the sag stiffness, the
fastener (screws, cable ties or tape) and the materials section of Gemini's prompts, so the AI and the
validator never disagree.

## The contrast

The same photo goes to Gemini as a plain chatbot ("give me a cut list"), with no tools, and its answer goes
through the same validator. With panel furniture the chatbot gives cut lists that ignore saw margins, screw
holes and damage. With plastic or cardboard it usually gives up ("this can't become a bench"). Ginkgo instead
finds a safe reuse and proves it.

## Proof that the code is right

- 170+ unit tests in the `GinkgoCore` Swift package, each logic file at 85% coverage or more, strict lint,
  warnings treated as errors (`scripts/ci-core.sh`, run by `scripts/ci.sh` and GitHub Actions).
- `scripts/prove-tests-core.sh` plants eight known bugs (the saw margin, an off-by-one fit, touching cuts, the
  sag limit, damaged parts, plan acceptance, the parts-reader flag, stability) and shows a test catches each.
- `ginkgo-live eval` runs the real agent across variants; results are in `build/eval.md`.

## AI used to build Ginkgo

The team used Claude Code to write code and tests under strict rules: a test for every function, a
deliberate-bug proof for every feature, and CI before every commit.
