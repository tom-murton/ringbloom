# Flower Show UI and accessibility verification matrix

Issue: TOM-61  
Prepared: 10 August 2026  
Candidate: build 6 (manual execution to be completed with TOM-65)

This matrix distinguishes automated evidence from pending manual checks. A pending row is
not a pass. Failed or aborted runners must be recorded separately and must not be cited as
coverage.

TOM-65 execution evidence is recorded in
[the 10 August build-6 physical/accessibility checklist](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/TOM65_BUILD6_PHYSICAL_ACCESSIBILITY_EVIDENCE_2026-08-10.md>).
The final source-matched physical helper passed 128/128 logical Swift tests (205 executions) and
all 39 UI tests on the wired iPhone SE / iOS 26.6. The two earlier automation-mode failures and
the intermediate nine-test harness diagnostic are retained separately. The helper installs an
Apple Development test product, so this is physical automated UI evidence rather than proof of the
uploaded TestFlight binary hash. Every manual VoiceOver, perceptual, commerce and StoreKit row
below remains pending.

## Automated UI journeys

| Plan requirement | Named XCTest coverage | Evidence status |
|---|---|---|
| Fresh Home shows 0/1 Garden won during production-equivalent checking | `testFreshHomeShowsQualificationProgressDuringProductionEquivalentChecking` | Passed — `tom59-ui-progress-green.xcresult` |
| Garden 1 qualification transition remains visible | `testQualifiedHomeKeepsOneOfOneTransitionVisibleWhileAccessChecks`; Swift test `firstGardenWinExposesOneOfOneDuringChecking` | Passed — `tom59-ui-progress-green.xcresult`; `tom57-61-swift-rerun.xcresult` |
| Winning Garden exposes Flower Show and Class Book | `testQualifiedPlayerSeesFreeSamplerAndClassBook` plus existing Garden flow | Passed — `tom61-ui-access-routes-green-final.xcresult` |
| Sample enters/replays Classes 1–5 | `testSampleAccessCanEnterAndReplayEveryFreeClassBoundary` | Passed in one automation session — `tom61-ui-free-boundary-green.xcresult`; repeated in final routes bundle |
| Class 5 result remains before purchase | `testResultCheckingThenSamplePreservesResultBeforeContinueOpensPurchase` | Passed — `tom57-ui-exact-fixture.xcresult` |
| Class 6 blocked from Home | `testSamplerOpensPurchaseAtClassSix` | Passed — `tom61-ui-access-routes-green-final.xcresult` |
| Class 6 blocked from Class Book | `testPremiumClassBookTileOpensPurchaseWithoutStartingGame` | Passed — `tom57-ui-replay-result.xcresult`; final routes bundle |
| Premium saved attempt cannot resume under sample | `testSavedPremiumAttemptCannotResumeUnderSampleAccess` | Passed — `tom61-ui-access-routes-green-final.xcresult` |
| Premium retry route remains gated | `testPremiumClassRetryCannotBeginUnderSampleAccess` | Passed — `tom61-ui-commerce-rerun.xcresult` |
| Paywall promises Classes 6–30 and Circuit, StoreKit price, Keep Playing, Restore | `testPaywallPromisesFullContentAndSupportsLongStorePrice`; `testSamplerOpensPurchaseAtClassSix` | Passed — `tom61-ui-access-routes-green-final.xcresult` |
| Cancellation preserves free access without error | `testCancelledPurchasePreservesFreeAccessWithoutShowingAnError` | Passed — `tom61-ui-commerce-rerun.xcresult` |
| Simulated purchase unlocks and routes to target | `testSimulatedPurchaseUnlocksAndRoutesToClassSixAndSelectedTarget` | Passed — `tom61-ui-commerce-rerun.xcresult` |
| Legacy override bypasses paywall | `testLegacyAccessBypassesPaywallAtClassSix` | Passed — `tom61-ui-access-routes-green-final.xcresult` |
| Checking never flashes/opens paywall; campaign and replay controls are actively exercised | Checking Class Book, campaign result and premium replay-result tests | Passed — `tom61-ui-checking-classbook-green.xcresult`; `tom57-ui-exact-fixture.xcresult`; `tom57-ui-replay-result.xcresult` |
| Checking → full starts expected campaign/replay Class | Campaign and premium replay checking→full tests | Passed — `tom57-ui-exact-fixture.xcresult`; `tom57-ui-replay-result.xcresult` |
| Checking → sample retains campaign/replay result, then opens purchase | Campaign and premium replay checking→sample tests | Passed — `tom57-ui-exact-fixture.xcresult`; `tom57-ui-replay-result.xcresult` |
| Product unavailable, pending and failed exact copy/actions | `testPendingFailedAndUnavailablePurchaseStatesShowExactRecoveryCopy` | Passed — `tom61-ui-states-layout.xcresult` |
| Purchases-disabled exact copy/actions | `testPurchasesDisabledShowsExactCopyAndFreeAndRestoreActions` | Passed — `tom61-ui-commerce-states-rerun.xcresult` |
| Historical premium ratings remain visible but gated | `testSamplerRetainsHistoricalPremiumRatingWhileGated` | Passed — `tom61-ui-access-routes-green-final.xcresult` |
| Restore success routes to correct target | `testRestoreSuccessUnlocksAndRoutesToClassSix` | Passed — `tom61-ui-commerce-states-rerun.xcresult` |
| Purchase/restore in-flight controls disabled | `testPurchaseAndRestoreInFlightDisableBothStorefrontControlsAndExposeFeedback` | Passed — `tom61-ui-commerce-states-rerun.xcresult` |
| Stable accessibility identifiers | Exercised throughout the named suite; checking result IDs asserted directly | Passed across the green bundles below |
| Compact and current-large simulator layout | Stable compact matrix on iPhone 13 mini; complete target on current Pro | iPhone 13 mini 5/5 passed; iPhone 17 Pro full target 39/39 passed |
| Final physical UI automation on the test iPhone | Complete `RingbloomUITests` target | iPhone SE / iOS 26.6: 39/39 passed — [source-matched physical result](</Users/tommurton/Library/Developer/Xcode/DerivedData/Ringbloom-ekhndzksekjkwghedtgicyqvimkg/Logs/Test/Test-Ringbloom-2026.08.10_11-25-37-+0100.xcresult>) |
| Accessibility XXXL, Increased Contrast and Reduce Motion | `testReducedMotionAndIncreasedContrastKeepLateClassControlsReachable`; expanded manual rows below | Passed — `tom61-ui-states-layout.xcresult`; manual AT checks remain pending TOM-65 |

### Green automated evidence

All paths are relative to the project root and resolve under `.build/`:

- `tom57-61-swift-rerun.xcresult` — focused TOM-57–59 Swift suites passed.
- `tom58-repair-conflict.xcresult` — V3 real-store validation, including a mismatched
  pre-existing repair backup failing closed, passed.
- `tom59-ui-progress-green.xcresult` — qualification progress 2/2 passed.
- `tom57-ui-exact-fixture.xcresult` — deterministic campaign result checking 3/3 passed.
- `tom57-ui-replay-result.xcresult` — premium replay-result checking and Class Book route 3/3 passed.
- `tom61-ui-commerce-rerun.xcresult` — cancellation, premium retry and success routing 3/3 passed.
- `tom61-ui-commerce-states-rerun.xcresult` — purchases disabled, restore success and in-flight states 3/3 passed.
- `tom61-ui-free-boundary-green.xcresult` — Classes 1–5 replayed and returned to Class Book in one session.
- `tom61-ui-access-routes-green-final.xcresult` — final access-route batch 9/9 passed.
- `tom61-ui-states-layout.xcresult` — recovery copy, purchase return and automated accessibility layout 5/5 passed.
- `tom61-ui-compact-layout-final.xcresult` — source-matched iPhone 13 mini compact/layout matrix 5/5 passed.
- `tom61-ui-full-current-large-source-frozen.xcresult` — source-matched complete
  `RingbloomUITests` target on iPhone 17 Pro / iOS 26.5: 39 passed, zero failures/skips.

### Preserved failed or aborted evidence

These bundles are diagnostic evidence and are not counted as coverage:

- `tom61-ui-commerce.xcresult` — 3/6 failed before route/query fixes.
- `tom61-ui-commerce-states.xcresult` — 1/3 failed with the earlier Home-entry harness.
- `tom57-59-ui.xcresult` — 3/5 failed with the timing-sensitive hint-driven win fixture.
- `tom57-ui-result-rerun.xcresult` — 3/3 failed before the exact-solver fixture.
- `tom61-ui-access-routes.xcresult` — checking Class Book AX enabled-state failure.
- `tom61-ui-checking-classbook-rerun.xcresult` — intermediate modifier-order run lost the identifier.
- `tom61-ui-access-routes-green.xcresult` — Class 8 was only partially visible when tapped.
- `tom61-ui-access-routes-final.xcresult` — multi-launch free-Class replay harness flake.
- `tom61-ui-free-boundary-rerun.xcresult` — deliberately aborted while replacing five relaunches with one stable session.
- `tom61-ui-full-current-large.xcresult`, `tom61-ui-full-current-large-clean.xcresult` and
  `tom61-ui-full-current-large-final.xcresult` — deliberately aborted at successive source freezes;
  none is counted as final coverage.

## Static accessibility audit

### P0

None found. All Flower Show gameplay continues to expose semantic ring and rotation controls;
the result access check does not introduce a gesture-only path.

### P1

- Pending physical VoiceOver verification for focus retention when a disabled Checking Access
  action becomes enabled or routes to purchase.
- Pending physical verification of checking, purchasing, restoring, pending, failed and success
  announcements. XCTest labels and values are necessary evidence but do not prove speech timing.
- Pending Voice Control, Switch Control and Full Keyboard Access traversal of the complete
  purchase/result journey.

### P2 addressed in source

- The result Continue action changes visible and accessible label/value while checking, is
  disabled, and exposes a separate 44-point retry action.
- The result and earned rating remain in the accessibility tree throughout checking and retry.
- Fresh and newly-qualified Home states expose `0 of 1` and `1 of 1 Garden won` before
  entitlement resolution; visible detail simultaneously describes the checking state.
- Sample and full access expose distinct free-Class and campaign progress values.
- Result, purchase and Home layouts remain scrollable and use Dynamic Type text styles.
- Existing transitions continue to branch on Reduce Motion; no new checking animation was added.

Regression risk is moderate around result focus timing and StoreKit transition announcements;
the state and persistence changes themselves have focused automated coverage.

## Manual build-6 accessibility matrix

Each journey must be run with VoiceOver first. Repeat the visual/layout column at Accessibility
XXXL and Increased Contrast. Repeat transitions with Reduce Motion. Record device, OS, build,
date, tester, result and evidence path for every executed row.

| State/transition | VoiceOver expected result | Visual/layout expected result | Compact iPhone | Current large iPhone | Status |
|---|---|---|---|---|---|
| Fresh unqualified + checking | Heading → qualifier copy → `0 of 1 Garden won` → disabled Flower Show, with no purchase announcement | No missing progress row or launch jump | Pending | Pending | Pending TOM-65 |
| Garden 1 win → qualified + checking | Garden result remains intelligible; Home announces `1 of 1 Garden won` and checking copy | Qualification completion remains visible before entitlement resolves | Pending | Pending | Pending TOM-65 |
| Qualified checking result after Class 5 | Focus enters result heading; rating follows; Continue says Checking Access and is dimmed; retry is reachable | Rating/result do not disappear; no paywall flash | Pending | Pending | Pending TOM-65 |
| Checking retry → full | Focus does not jump behind result; Continue label/value becomes ready | Result remains until Continue; Class 6 briefing follows | Pending | Pending | Pending TOM-65 |
| Checking retry → sample | Continue becomes ready without announcing purchase early | Result remains until Continue; purchase opens only on activation | Pending | Pending | Pending TOM-65 |
| Purchase idle with deliberately long localised price | Heading, promise, benefits, price action, Keep Playing and Restore have concise names/roles | Price wraps without truncating or obscuring actions | Pending | Pending | Pending TOM-65 |
| Purchase in flight | Progress is announced once; purchase and Restore report disabled state | No duplicate spinner/copy; layout remains stable | Pending | Pending | Pending TOM-65 |
| Restore in flight | Restore progress announced once; purchase and Restore report disabled state | Same as purchase in flight | Pending | Pending | Pending TOM-65 |
| Pending purchase | Heading and approval copy announced; Keep Playing is reachable | No error treatment; free route remains visible | Pending | Pending | Pending TOM-65 |
| Failed purchase | Failure heading/copy, Try Again, Keep Playing and Restore read in order | Error is not conveyed by colour alone | Pending | Pending | Pending TOM-65 |
| Purchases disabled | Unavailable-on-device copy plus free and Restore actions | Controls do not clip at XXXL | Pending | Pending | Pending TOM-65 |
| Product unavailable | Temporary-unavailable copy plus Try Again, Keep Playing and Restore | No empty price/action placeholder | Pending | Pending | Pending TOM-65 |
| Purchase success → Class 6 | Unlocked heading receives focus; target action names Class 6 | No transient return to paywall | Pending | Pending | Pending TOM-65 |
| Purchase success → gated/non-current target | Unlocked heading then Back to Class Book | Does not start a progression-locked Class | Pending | Pending | Pending TOM-65 |
| Restore success | Unlocked heading and correct target routing | No intermediate error or Home flash | Pending | Pending | Pending TOM-65 |
| Cancellation | Returns to prior Home/Class Book/result context without error announcement | Garden and Classes 1–5 remain available | Pending | Pending | Pending TOM-65 |
| Historical premium rating under sample | Tile announces Class, completion/rating and Full Show requirement | Rating remains visible with non-colour lock cue | Pending | Pending | Pending TOM-65 |
| Reduce Motion checking/purchase/success | Same focus order and labels; no animation-dependent announcement | Transitions use fades/immediate updates without spatial sweep | Pending | Pending | Pending TOM-65 |

## Manual assistive-technology passes

- [ ] VoiceOver rotor: Home, Class Book, result and purchase headings appear once and in order.
- [ ] VoiceOver controls: labels omit trait words; values carry progress/state; hints add only
  non-obvious context; disabled controls announce unavailable/dimmed.
- [ ] VoiceOver modal focus: opening and closing Class Book, result and purchase never exposes
  background gameplay and restores useful focus.
- [ ] Voice Control: visible action names activate every Home, result and purchase action.
- [ ] Switch Control: complete the result → retry → Continue/purchase path without a touch gesture.
- [ ] Full Keyboard Access: focus order follows visual order; activation and Escape/back paths work.
- [ ] Accessibility XXXL: no clipped copy or inaccessible action in every state row above.
- [ ] Increased Contrast and Differentiate Without Colour: locks, completion, error and success
  remain distinguishable through text, symbols, stroke or trait—not colour alone.
- [ ] Reduce Motion: no parallax/spatial transition remains essential to understanding state.
- [ ] Grayscale/colour filters: ratings, locks, selection and result status remain distinguishable.

## Evidence recording

For automated batches, add exact absolute `.xcresult` links only after a clean pass. Preserve
separate result bundles for compact and large simulators. Record any aborted runner in a distinct
failed-runs subsection with the last completed test; never merge it into the pass count.

For manual rows, store screenshots or short screen recordings under a build-6 evidence directory
and enter their absolute paths in this document during TOM-65. VoiceOver timing observations must
be written as notes; a silent screenshot cannot prove focus or announcement behaviour.
