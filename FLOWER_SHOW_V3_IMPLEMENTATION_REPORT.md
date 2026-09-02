# Flower Show V3 implementation report

**Date:** 1 August 2026  
**Overall verdict:** **GO for physical-device testing**

Flower Show V3 is implemented, builds successfully, passes exact content certification, passes the required fresh route-blind review and now passes the complete final test suite on both target Simulators. Final raw and designed screenshots have also been recaptured, inspected and size-validated from the same certified app build. No physical-iPhone test, signing, archive, upload or TestFlight action has been started.

## Gate summary

| Gate | Result | Evidence |
|---|---|---|
| V3 feature implementation | PASS | Production sources, UI, persistence, tests and authoring target compile together |
| Frozen Garden regression boundary | PASS | Existing Garden engine and journeys pass on both final Simulator destinations |
| Exact 166-fixture content certification | PASS | 30 campaign, 8 curated Circuit and 128 endless Circuit fixtures |
| Fresh route-blind review | PASS | 146 late-game/Circuit fixtures, 292 visible-state witnesses |
| Debug iOS Simulator build after final catalogue | PASS | Generic Simulator build completed |
| Release iOS Simulator build after final catalogue | PASS | Generic Simulator build completed |
| App, unit-test and UI-test build after final catalogue | PASS | `build-for-testing` completed for all three targets |
| Fresh final Simulator execution | PASS | 71/71 on iPhone 17 Pro and 71/71 on iPhone 13 mini; zero failures or skips |
| Final screenshot capture and validation | PASS | 7 raw captures; 7 designed 1242×2688 panels; zero validation errors or warnings |
| Physical iPhone | READY, NOT STARTED | Simulator gate is complete; attached-device checks remain the next phase |

## Delivered implementation

The update replaces the old Flower Show path with a separately modelled V3 game while preserving Garden's existing identity and engine.

- A pure Flower Show state model and reducer now own all turn behaviour. Production play, authoring and the exact solver use the same rules.
- The campaign contains 30 authored Classes. Champion Circuit adds Classes 31–38 followed by a deterministic cycle over 128 fully materialised fixtures.
- Flower Show now supports Bloom targets, Harmony, Unbroken, Bindweed, Twin Bloom, Prize Bouquet and Judges' Order.
- Undo restores the exact prior state and permanently applies its rating consequence. Hint, par and assistance consequences are reflected by the live best-available rating.
- Ratings, replay, sequential progression, Grand Champion, Champion Circuit and Perfect Show are derived from minimal persisted state.
- The exact async Hint service has canonical state keys, cache reuse, request deduplication, cancellation and explicit timeout/no-route states. Ring interaction remains independent of solver work.
- UI work includes the Class Book, briefing and result flows, compact live Goals rail, rule introductions, saved-attempt replacement, Circuit presentation and distinct selection/Hint/Bindweed-preview treatments.
- Accessibility work includes redundant colour/shape cues, complete objective summaries, merged turn announcements, Dynamic Type layouts, Increased Contrast and Reduced Motion handling.
- Persistence now uses typed version-first loading, atomic V3 saves, raw V1/V2 migration fixtures, recoverable legacy salvage and a no-overwrite failure path for corrupt data.
- A macOS `FlowerShowAuthoring` target performs deterministic fixture authoring, exact route certification, strategy diagnostics, directional peak comparisons and report generation.

Principal implementation files:

- `Ringbloom/Sources/FlowerShowModel.swift`
- `Ringbloom/Sources/FlowerShowReducer.swift`
- `Ringbloom/Sources/FlowerShowSolver.swift`
- `Ringbloom/Sources/FlowerShowContent.swift`
- `Ringbloom/Sources/FlowerShowProgress.swift`
- `Ringbloom/Sources/FlowerShowViews.swift`
- `Ringbloom/Sources/FlowerShowClassBookView.swift`
- `Ringbloom/Sources/FlowerShowResultView.swift`
- `Ringbloom/Sources/GameModel.swift`
- `Tools/FlowerShowAuthoring.swift`
- `RingbloomTests/FlowerShowTests.swift`
- `RingbloomUITests/RingbloomUITests.swift`

`project.yml` and the generated Xcode project are reconciled sufficiently for the app, authoring tool and both test bundles to build. The folder is not a Git repository, so no commit is claimed.

## Content and balance certification

The final catalogue contains exactly 166 accepted fixtures:

| Scope | Count |
|---|---:|
| Campaign Classes 1–30 | 30 |
| Curated Circuit Classes 31–38 | 8 |
| Endless Circuit catalogue | 128 |
| **Total** | **166** |

Final campaign table:

| Class | Bloom target | Exact shortest | Moves | Radiant par | Special objectives |
|---:|---:|---:|---:|---:|---|
| 1 | 5 | 5 | 9 | 6 | Harmony 1/ring |
| 2 | 6 | 5 | 9 | 6 | Harmony 1/ring |
| 3 | 6 | 4 | 8 | 5 | Harmony 1/ring |
| 4 | 6 | 5 | 8 | 6 | Harmony 1/ring |
| 5 | 7 | 5 | 8 | 6 | Harmony 1/ring |
| 6 | 5 | 4 | 8 | 5 | Unbroken 2 |
| 7 | 6 | 4 | 8 | 5 | Unbroken 3 |
| 8 | 6 | 5 | 8 | 6 | Harmony 1/ring; Unbroken 2 |
| 9 | 7 | 5 | 9 | 6 | Harmony 1/ring; Unbroken 3 |
| 10 | 7 | 6 | 8 | 6 | Harmony 1/ring; Unbroken 4 |
| 11 | 5 | 4 | 8 | 5 | Bindweed 1 |
| 12 | 6 | 5 | 8 | 6 | Harmony 1/ring; Bindweed 1 |
| 13 | 6 | 5 | 8 | 6 | Unbroken 3; Bindweed 1 |
| 14 | 7 | 6 | 9 | 7 | Harmony 1/ring; Bindweed 2 |
| 15 | 8 | 6 | 9 | 7 | Harmony 1/ring; Unbroken 3; Bindweed 2 |
| 16 | 5 | 4 | 8 | 5 | Twin Bloom 1 |
| 17 | 6 | 5 | 8 | 6 | Harmony 1/ring; Twin Bloom 1 |
| 18 | 7 | 5 | 9 | 6 | Unbroken 3; Twin Bloom 1 |
| 19 | 7 | 6 | 9 | 7 | Bindweed 2; Twin Bloom 1 |
| 20 | 8 | 7 | 9 | 7 | Harmony 1/ring; Bindweed 2; Twin Bloom 1 |
| 21 | 6 | 5 | 9 | 6 | Bouquet 4 kinds |
| 22 | 7 | 5 | 9 | 6 | Harmony 1/ring; Bouquet 4 kinds |
| 23 | 7 | 6 | 9 | 7 | Bindweed 2; Bouquet 4 kinds |
| 24 | 7 | 6 | 9 | 7 | Harmony 2/ring |
| 25 | 9 | 6 | 9 | 7 | Harmony 2/ring; Twin Bloom 1; Bouquet 4 kinds |
| 26 | 8 | 5 | 9 | 6 | Harmony 1/ring; Twin Bloom 2 |
| 27 | 8 | 6 | 10 | 7 | Harmony 1/ring; Unbroken 4; Bindweed 2 |
| 28 | 9 | 7 | 10 | 8 | Unbroken 4; Bindweed 2; Bouquet 4 kinds |
| 29 | 10 | 7 | 10 | 8 | Harmony 2/ring; Unbroken 5; Twin Bloom 2 |
| 30 | 11 | 7 | 10 | 8 | Harmony 2/ring; Bindweed 3; Bouquet 4 kinds |

For Bindweed, the number is the count of initially tangled spokes. `Harmony 2/ring` requires two qualifying blooms on each ring. The complete fixture-level table, including all 136 Circuit entries and their reference routes, is in the generated certification report.

The exact certification result is **PASS**:

- every fixture has a repair-free exact winning reference route;
- all fixture-specific strategy bands, decision counts, forced-run limits and late-game diagnostics pass;
- all 46 directional comparisons across the 23 required peak relationships pass;
- cold exact solving in the local Mac Release authoring binary measured 13.03 ms median, 144.65 ms p95 and 634.99 ms maximum;
- 151 planned Radiant-par values were adjusted by one move to remain honest against the authored exact shortest route;
- 10 move budgets were tightened by one move: Campaign 20, 25 and 30, plus Circuit R8 variants 05, 06, 07, 08, 09, 13 and 15.

Those deviations are within the plan's explicit ±1 authoring allowance and are enumerated with reasons in the certification report. The final campaign peaks are solver-safe, including Class 20 at 9 moves/par 7, Class 25 at 9/par 7, Class 30 at 10/par 8 and the intended releases at Classes 26 and 29.

Integrity values:

| Artefact | SHA-256 |
|---|---|
| `Ringbloom/Resources/FlowerShowV3Catalog.json` | `59aaca1032d81c2bdc059a85e0e18fc4a3ae80803c52427f00e9051a709c7624` |
| `FLOWER_SHOW_V3_CERTIFICATION_REPORT.md` | `81625868f78046cc8af73edc8e241ace207283d06527e399b73c17bc9cc5ddd3` |
| Recoverable pre-change baseline | `400e4426487df6714cb009691faf8886853452ab63b3cb0ceecb10d8156a7b25` |

## Fresh route-blind review

A fresh agent was given no reference routes, certification report, tests or planning commentary. It inspected Classes 21–38 and all 128 endless Circuit fixtures using only visible board and objective state.

Result: **PASS**

- 146/146 fixtures met the required criterion.
- 292/292 visible-state decision/failure witnesses were found.
- 882 hidden-refill-cursor substitutions did not change the selected or comparison move.
- 144 fixtures produced both witnesses within two adaptive turns; the remaining two needed a third visible turn because their initial scoring choices were equivalent.

This establishes local explainability, not human difficulty calibration or proof that every puzzle has two deep strategic branches. The reviewer correctly kept that limitation explicit.

## Test and build evidence

### Complete Simulator runs before the final catalogue rebalance

| Destination | Result | Tests |
|---|---|---:|
| iPhone 17 Pro, iOS 26.5 | PASS | 56 Swift tests |
| iPhone 17 Pro, iOS 26.5 | PASS | 15 UI tests |
| iPhone 13 mini, iOS 26.2 | PASS | 71 combined tests |
| iPhone 17 Pro after the final visual fixes | PASS | 3 affected UI tests |
| iPhone 13 mini after the final visual fix | PASS | 1 affected UI test |

All of these `.xcresult` bundles report zero failures, zero skips and zero expected failures. Parameterised Swift tests expand beyond the 56 declared test cases internally, but the Xcode summary correctly reports 56 test cases.

### Verification after the final catalogue rebalance

- `FlowerShowAuthoring`, Release macOS: **build PASS**.
- Ringbloom, Debug generic iOS Simulator: **build PASS**.
- Ringbloom, Release generic iOS Simulator: **fresh build PASS on 1 August**.
- Ringbloom app + `RingbloomTests` + `RingbloomUITests`: **build-for-testing PASS**.
- Final exact catalogue certification: **PASS**.
- Fresh route-blind review: **PASS**.

### Final Simulator execution — 1 August 2026

| Destination | Result | Swift tests | UI tests | Total | Failures | Skips |
|---|---|---:|---:|---:|---:|---:|
| iPhone 17 Pro, iOS 26.5 | PASS | 56 | 15 | 71 | 0 | 0 |
| iPhone 13 mini, iOS 26.2 | PASS | 56 | 15 | 71 | 0 | 0 |

The two executions used separate fresh Derived Data directories. The Xcode result bundles are `.build/v3-20260801-17pro.xcresult` and `.build/v3-20260801-13mini.xcresult`; both report `Passed`, 71 test cases, zero failures, zero skips and zero expected failures. Parameterised Swift cases expanded to 122 device/configuration executions in each result.

### Final screenshot evidence

Seven deterministic screenshots were recaptured from the final iPhone 17 Pro test build with a fixed 09:41 Simulator status bar:

- Home;
- Class Book;
- Class 11 Bindweed introduction;
- live Class 30 Grand Final;
- Class 33 Judges' Order introduction;
- Champion Circuit home;
- the Radiant Grand Champion result.

The untouched full-resolution originals are in `screenshots/flower-show-v3/raw`. A separate deterministic composition step scales each capture as one unretouched layer inside a modern branded background with concise campaign copy; it does not generate or repaint any app UI. Those seven panels are in `screenshots/flower-show-v3/showcase`.

All showcase files are 1242×2688. `asc screenshots validate --device-type APP_IPHONE_65` reports 7/7 ready, zero errors and zero warnings. The composition was visually inspected for content accuracy, legibility, clipping and consistency.

Reusable capture and composition tools:

- `Tools/capture-flower-show-v3-screenshots.sh`
- `Tools/compose-flower-show-v3-screenshots.py`

## Physical-device hand-off

The Simulator gate is complete. The project is ready to move to the attached iPhone using `Ringbloom.xcodeproj`, scheme `Ringbloom`.

The physical phase must still verify:

- the helper's final `PHYSICAL_IPHONE_TESTS_PASSED` line;
- cold exact-Hint median, p95, worst-case and peak memory on real hardware;
- touch behaviour and control reachability;
- haptics and audio behaviour;
- VoiceOver focus and turn announcements;
- real-device Dynamic Type, Increased Contrast and Reduced Motion.

No App Store Connect query, build-number change, archive, export, upload, tester assignment or AI-content declaration has been performed.
