# Ringbloom 1.2 freemium Flower Show implementation report

Original evidence date: 9 August 2026  
Evidence hygiene revision: 10 August 2026

## Status

The source implementation now has a source-matched version 1.2/build 6 release candidate archived, exported, inspected and staged in App Store Connect. It is not yet production-ready: the remaining gates are the physical assistive-technology work, real Apple sandbox/TestFlight commerce checks, and Tom's final two-item draft/App Privacy inspection.

**Version 1.2/build 5 is superseded.** Its archive and IPA predate subsequent source and test changes, so build 5 remains historical evidence only and must not be used to substantiate the current source. Version 1.2/build 6 is the current candidate; staging it does not by itself close the remaining human, device and real-StoreKit gates.

The original plan’s hyphenated product ID was rejected by Apple. The minimal valid equivalent remains:

`com.tommurton.ringbloom.flower_show`

The locked implementation plan remains unchanged benchmark evidence.

## Implemented source changes

- Serialised entitlement refresh results so an older asynchronous snapshot cannot overwrite a newer purchase or revocation decision.
- Made verified revocation downgrade store access immediately and refresh without re-granting the revoked purchase.
- Preserved established legacy paid-app access when StoreKit cannot temporarily read the app transaction.
- Disabled purchase while the StoreKit product is still loading.
- Preserved purchase-screen routing from Home and Class Book.
- Kept historical Class Book ratings visible while showing the full-show gate.
- Added deterministic access, purchase, restore, race, revocation, routing and accessibility tests.
- Added a DEBUG-only hosted-unit-test composition path that uses a no-I/O store client; Release and Archive composition always construct `StoreKitFlowerShowStoreClient`.
- Made Flower Show screenshot capture require an explicit app bundle, version and build, and reject mismatched candidates before installation.

## Release-candidate evidence ledger

### Superseded historical build 5

| Field | Recorded evidence |
|---|---|
| Version/build | 1.2 (5) |
| Archive creation time | 9 August 2026, 19:43:22 BST |
| IPA creation time | 9 August 2026, 19:43:30 BST |
| IPA | [Ringbloom-1.2-5.ipa](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build5/Ringbloom-1.2-5.ipa>) |
| IPA SHA-256 | `7035d66ca220ad155d69b549c35418a93cd03033e0094ad30cc037c1ebcece44` |
| Historical ASC build | Build ID `e0a557aa-d751-4154-af58-b197c8e3e698` |
| Source relationship | Superseded: eight source/test files in the current workspace postdate the IPA |
| Packaged `.storekit` | None found in the IPA |

### Current build 6 candidate

| Field | Current record |
|---|---|
| Evidence timestamp | 10 August 2026; build-6 evidence directory created 08:00:34 BST; upload read-back completed 08:30:36 BST |
| Source revision | No Git revision is available; the [49-file build-6 source manifest](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/source/build6-source-files.sha256>) has SHA-256 `f9f30dc0905f82a867d7c159256689d25dc22ed395e18d74cf2b0f7d3427416b`. Against the final build-5 freeze, only `project.yml` and generated `project.pbxproj` changed, both solely for build 6; the manifest was unchanged before and after testing, analysis, archive and upload. |
| Archive time/path/hash | 10 August 2026, 08:24:30–08:25:04 BST; [Ringbloom-1.2-6.xcarchive](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/archive/Ringbloom-1.2-6.xcarchive>); [archive file manifest](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/archive/archive-files.sha256>) SHA-256 `e7fc4684414642a71802a0827b7ddd745e36112efb7d28939815300686bb6d85` |
| Version/build | 1.2 (6), bundle ID `com.tommurton.ringbloom`, minimum iOS 17.0 |
| IPA path/hash | [Ringbloom-1.2-6.ipa](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/export/Ringbloom-1.2-6.ipa>), created 08:26:09 BST, 3,293,260 bytes, SHA-256 `57a1ed81256ac0746975047c5e0c2d4b14a3912595be613799e2848d71d2aff4` |
| App Store Connect build ID | `a3434f64-3bf5-484a-9f6d-6daf0a0a3b92`; [independent build read-back](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/readback/build6-by-id.json>) is `VALID` |
| Tested source → archive → staged binary proof | Passed: one immutable 49-file manifest remained unchanged; the archive and distribution-signed IPA both identify 1.2 (6); the exact hashed IPA was uploaded; ASC returned the recorded build ID as 1.2/build 6 and that ID is attached to version 1.2. |

The build-6 binary identity gate is closed. This does not replace the remaining physical-device, real sandbox/TestFlight commerce or human submission checks.

## Automated evidence and traceability

### Version 1.2/build 6 — source-matched release gate

- [Complete clean Ringbloom scheme result](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/test/Ringbloom-build6-full.xcresult>), [log](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/test/Ringbloom-build6-full.log>), [summary](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/test/Ringbloom-build6-full-summary.json>) and [execution-count derivation](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/test/execution-count-derivation.txt>) record **167 logical tests, 244 executions, zero failures and zero skips**, including **39/39 UI tests**. The run used a brand-new no-account iPhone 17 Pro / iOS 26.5 simulator (`FCB43C2A-5F90-4EFC-9DF9-D0E232E2FF88`) and unique DerivedData.
- The test command reached `** TEST SUCCEEDED **`; the xcresult independently reports `Passed`. The preserved [wrapper qualification](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/test/wrapper-exit-qualification.md>) records a later shell-only failure caused by assigning zsh's read-only `status` variable; no clean wrapper exit is claimed.
- The [targeted runtime scan](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/test/Ringbloom-runtime-scan-summary.txt>) examined 339,027 timestamped Ringbloom process lines and found zero StoreKit, AppTransaction, account, authentication or network-attempt markers.
- [Release clean analysis](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/release-analysis/Release-analyze.log>) succeeded with exit 0; SHA-256 `d37d36057c59520c5343d3c49ad7563698cdad43b62bc3ce956a9f8269d24b30`.
- The [IPA inspection summary](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/inspection/ipa-inspection-summary.txt>) and [strict signature verification](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/inspection/ipa-codesign-verify.txt>) record an arm64 App Store distribution build signed by `Apple Distribution: Tom Murton (5R8P82H779)` with profile `Ringbloom App Store 2026`, UUID `1ff2ee44-3d91-4de2-8148-31625ad9cf7e`, `get-task-allow=false`, a packaged privacy manifest, StoreKit linkage and production product/copy strings. There are zero packaged `.storekit` files and zero hosted-test markers.
- [Upload result](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/upload/upload-result.json>), [version attachment read-back](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/readback/version-after-attach.json>) and [internal Test-group link](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/readback/build6-test-group-link.json>) prove that this exact IPA became `VALID`, is available to the internal all-build `Test` group and replaced build 5 on the prepared version 1.2 record.

### Current frozen source — canonical final pre-build gate

- [Clean no-account RingbloomTests result](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.build/tom64-prebuild-final2-20260810T064412Z/RingbloomTests.xcresult>), [full log](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.build/tom64-prebuild-final2-20260810T064412Z/RingbloomTests.log>) and [machine-readable summary](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.build/tom64-prebuild-final2-20260810T064412Z/RingbloomTests-summary.json>) record **128 logical tests in 14 suites, 205 parameterised executions, zero failures and zero skips**. The run used the brand-new `Ringbloom TOM64 Final2 20260810T064412Z` iPhone 17 Pro simulator (`427003A4-029E-46C0-8D25-116BFA33E479`) on iOS 26.5 and unique DerivedData.
- The saved [hosted-app runtime lines](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.build/tom64-prebuild-final2-20260810T064412Z/RingbloomTests-runtime-app-process.log>) and [targeted scan summary](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.build/tom64-prebuild-final2-20260810T064412Z/RingbloomTests-runtime-scan-summary.txt>) found zero StoreKit, AppTransaction, account, authentication or network-attempt markers across all 12 timestamped hosted-app process lines. The recorded lines contain only simulator audio/plugin diagnostics.
- `FlowerShowStoreClientCompositionTests.hostedTestCompositionIsExplicitAndDebugOnly` passed in the canonical result. [Release clean analysis](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.build/tom64-prebuild-final2-20260810T064412Z/Release-analyze.log>) succeeded; the [Release static summary](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.build/tom64-prebuild-final2-20260810T064412Z/Release-static-summary.txt>) records StoreKit linkage for both simulator architectures, the production `StoreKitFlowerShowStoreClient`, zero hosted-test markers, zero DEBUG Release conditions and zero packaged `.storekit` files. The inspected local product remains 1.2/build 5 and is not a release candidate.
- The check-only style inventory did not modify source. With no repository SwiftFormat/SwiftLint configuration or baseline, default SwiftFormat 0.55.5 reported [488 findings across 16 of 27 files](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.build/tom64-prebuild-final2-20260810T064412Z/SwiftFormat.json>), while default SwiftLint 0.58.2 with `--strict` reported [271 findings](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.build/tom64-prebuild-final2-20260810T064412Z/SwiftLint.json>). These are pre-existing default-policy style findings retained as non-mutating debt, not claimed passes.
- Evidence hashes: test log `079000fb4c4abec13b25c73d2528947b8d6f68c319427c4511413b2356fb4f6f`; test summary `aa3531e2930cb22d5494e3e0bc592c59b02d539976bb1a55c908292a4a05a47a`; xcresult per-file manifest `35f6656fda95e54bd8a2a1543168ff334e8a22e699d871af4e06244d1292978b`; Release analysis log `b9aed4d1fddd7bae2b4b8f48c16d879b19c73fd40ac5f61245dc4fccc98aadc0`.

### TOM-63 deterministic access-policy matrix

- [TOM-63 clean no-account Swift result](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.build/tom63-clean-20260810-RingbloomTests.xcresult>): **passed**, 119 logical tests (195 parameterised executions) in 14 suites, zero failures and zero skips, on the newly created `Ringbloom TOM63 Clean` iPhone 17 Pro simulator running iOS 26.5.
- [TOM-63 full hosted-test log](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.build/tom63-clean-20260810-RingbloomTests.log>) and saved [targeted runtime scan](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.build/tom63-clean-log-scan-20260810.log>): the StoreKit/account/authentication warning scan returned zero matches after excluding compile command/module names. Three unrelated `appintentsmetadataprocessor` warnings recorded that the app has no AppIntents dependency.
- [TOM-63 machine-readable summary](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.build/tom63-clean-20260810-summary.json>).
- Evidence hashes: log SHA-256 `6fda8d4d914ca33330d410debb4c27faced6ffb56bb3d0a0a215074536051368`; summary SHA-256 `6cc6af6678c2b7bc7c820f1f126f959f97e710d929077b0efc4d781d5f9131a4`.

Every row below is evidenced by the retained TOM-63 clean result above and was re-executed successfully in the canonical final result. Tests added after TOM-63 are identified separately below rather than attributed to the earlier bundle.

| Plan case | Required policy | Named Swift Testing coverage | Result bundle |
|---:|---|---|---|
| 1 | Qualification is false at highest Garden 1 and true after Garden 1 is won | `qualificationChangesOnlyAfterTheFirstGardenWin(highestGarden:)`; `firstGardenWinExposesOneOfOneDuringChecking()` | TOM-63 clean result |
| 2 | Qualified sample access permits Classes 1–5 and rejects Class 6, Class 30 and Circuit | `qualifiedSampleAccessPermitsOnlyClassesOneThroughFive(classNumber:)`; `sampleAccessAllowsFreeReplayAndRejectsEveryPremiumDirectOrReplayRoute()` | TOM-63 clean result |
| 3 | Full legacy and IAP access permit premium play while enforcing campaign sequence | `fullLegacyAndPurchaseAccessPermitPremiumButEnforceCampaignSequence(source:)` | TOM-63 clean result |
| 4 | Free replay works; premium replay and saved premium attempts require full access | `sampleAccessAllowsFreeReplayAndRejectsEveryPremiumDirectOrReplayRoute()`; `savedPremiumResumeAndRetryRequireFullAccess()`; `classFiveNextAndPrivatePremiumRetryCannotBypassSampleGate()` | TOM-63 clean result |
| 5 | Verified production original builds 1, 3 and 4 grant legacy access | `legacyAccessAcceptsOnlyVerifiedProductionBuildsBeforeFive(originalVersion:)` | TOM-63 clean result |
| 6 | Production original builds 5 and 10 do not grant legacy access | `legacyAccessRejectsTheNewBuildAndMalformedOrUntrustedValues(originalVersion:)` | TOM-63 clean result |
| 7 | Sandbox and Xcode original version 1.0 never grant legacy access | `nonProductionOriginalVersionOneNeverGrantsLegacy(environment:)` | TOM-63 clean result |
| 8 | Unverified or malformed AppTransactions fail closed without changing progress | `malformedAndUnverifiedAppTransactionsFailClosed()`; `untrustedAppTransactionFailsClosedWithoutMutatingProgress(appTransaction:)` | TOM-63 clean result |
| 9 | Only the exact verified, live product ID grants IAP access | `purchaseAccessRequiresTheExactVerifiedNonRevokedProduct()` | TOM-63 clean result |
| 10 | Missing, refunded or revoked IAP falls back to sample unless legacy exists | `purchaseOnlyRevocationWithEmptySnapshotBecomesSample()`; `purchaseOnlyRevocationFailureBecomesSample()`; `bothSourcesFallBackToLegacyAfterRevocation()`; `legacySurvivesRevocationWithUnavailableAppTransaction()` | TOM-63 clean result |
| 11 | Direct purchase and transaction update grant before finishing exactly once | `verifiedDeliveriesPublishAccessBeforeFinishingExactlyOnce()`; `duplicateListenerAndDirectPurchaseFinishesOnce()`; `duplicateRevokedUpdateFinishesExactlyOnce()` | TOM-63 clean result |
| 12 | Pending, cancellation, disabled purchase, product-load failure, restore and sync have distinct outcomes | `storefrontFailuresPublishDistinctStatesWithoutRemovingAccess()`; `cancellationDoesNotChangeAccessOrShowAnError()`; `productFailureLeavesValidEntitlementUntouched()`; `productionRestoreUsesSyncAndPreservesEstablishedAccessOnRefreshFailure()`; `restoreWithoutEntitlementReturnsToIdle()` | TOM-63 clean result |
| 13 | A transient refresh error cannot downgrade established in-memory entitlement incorrectly | `productionRestoreUsesSyncAndPreservesEstablishedAccessOnRefreshFailure()`; `bootstrapCompletionCannotEraseVerifiedUpdate()`; `laterOrdinaryRefreshPreservesVerifiedGrant()`; `ordinaryRefreshesCompleteInReverseOrder()` | TOM-63 clean result |
| 14 | Every Class 6+ route is gated, including replay, resume, retry, Next, saved and private-boundary attempts | `directModelEntryEnforcesQualificationAndPremiumBoundary()`; `sampleAccessAllowsFreeReplayAndRejectsEveryPremiumDirectOrReplayRoute()`; `savedPremiumResumeAndRetryRequireFullAccess()`; `classFiveNextAndPrivatePremiumRetryCannotBypassSampleGate()`; `activePremiumAttemptStopsMutatingAfterAccessIsLost()` | TOM-63 clean result |
| 15 | Existing V3 and Garden fixtures decode unchanged; ratings and active attempts survive access changes | `validV3FixtureIsPreservedExactly()`; `rawLegacySavePreservesGardenAndResetsOnlyFlowerShow(version:)`; `rawLegacyGardenContinuationIsDeterministic()`; `revocationPreservesPersistedPremiumProgress()` | TOM-63 clean result |
| 16 | Encoded GameProgress contains no entitlement Boolean | `encodedProgressContainsNoEntitlementState()` | TOM-63 clean result |

### Historical 9 August simulator evidence

- [Swift Testing result](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.build/freemium-fix/Logs/Test/Test-Ringbloom-2026.08.09_21-21-51-+0100.xcresult>): 72 tests in 12 named suites — `FlowerShowAccessPolicyTests`, `GameModelFlowerShowAccessTests`, `FlowerShowStoreTests`, `FlowerShowV3ContentTests`, `FlowerShowV3ReducerTests`, `FlowerShowV3SolverTests`, `FlowerShowV3ProgressTests`, `FlowerShowV3MigrationTests`, `GameBoardTests`, `BoardGestureInterpreterTests`, `GameEngineTests` and `GameModelTests`.
- [UI batch 1](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.build/freemium-fix/Logs/Test/Test-Ringbloom-2026.08.09_21-14-01-+0100.xcresult>): 10 named `RingbloomUITests`, including Class Book gating/routing, sampler purchase, rules, compact Home and tutorial continuity.
- [UI batch 2](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.build/freemium-fix/Logs/Test/Test-Ringbloom-2026.08.09_21-16-57-+0100.xcresult>): 11 named `RingbloomUITests`, including accessibility, bindweed, Class Book, Champion Circuit, migration, reduced motion and saved-attempt replacement.
- The combined 21-test run was attempted, but the simulator test runner was terminated mid-run. The two batch results above are the retained historical evidence.

| Behaviour | Named automated tests | Result bundle |
|---|---|---|
| Qualification, free Classes 1–5 and premium boundary | `qualificationRequiresTheFirstGardenWin`, `freeAndPremiumActionsRemainDistinct`, `directModelEntryEnforcesQualificationAndPremiumBoundary` | Historical Swift result |
| Active-session re-gating | `activePremiumAttemptStopsMutatingAfterAccessIsLost` | Historical Swift result |
| Legacy build cutoff | `legacyAccessAcceptsOnlyVerifiedProductionBuildsBeforeFive`, `legacyAccessRejectsTheNewBuildAndMalformedOrUntrustedValues` | Historical Swift result |
| Purchase/cancel/restore states | `verifiedPurchaseUnlocksAndFinishesExactlyOnce`, `cancellationDoesNotChangeAccessOrShowAnError`, `deterministicRestoreDoesNotContactStoreKit`, `productionRestoreUsesSyncAndPreservesEstablishedAccessOnRefreshFailure` | Historical Swift result |
| Verified revocation with refresh failure | `verifiedRevocationDowngradesEvenWhenEntitlementRefreshFails` | Historical Swift result |
| Current generation/race defences | `bootstrapCompletionCannotEraseVerifiedUpdate`, `laterOrdinaryRefreshPreservesVerifiedGrant`, `ordinaryRefreshesCompleteInReverseOrder`, `revocationInvalidatesOutstandingRefresh` | Canonical final result above; these tests were added after the historical bundle |
| Transaction-ID authority during suspended delivery, revocation and refresh | `revocationDuringSuspendedDirectFinishRemainsAuthoritative`, `revocationBeforeDelayedDirectSuccessRemainsAuthoritative`, `newerPurchaseInvalidatesSuspendedOlderRevocationRefresh`, `revocationRemovesOnlyItsOwnActiveTransaction` | Canonical final result above; these tests were added after TOM-63 |
| Class Book/purchase routing and checking state | `testCheckingAccessDoesNotOpenPurchaseFromClassBook`, `testClosingPurchaseFromClassBookReturnsToClassBook`, `testPremiumClassBookTileOpensPurchaseWithoutStartingGame`, `testSamplerRetainsHistoricalPremiumRatingWhileGated` | UI batch 1 |
| Hosted tests avoid the production client | `hostedTestCompositionIsExplicitAndDebugOnly` plus hosted-process StoreKit/auth/network scan | Canonical final result/log above |

This is test evidence for the named behaviours only; it is not a claim of complete state, race or production StoreKit coverage.

## Physical-device evidence

The signed build and 72 Swift tests completed on the attached iPhone, but the UI-test runner failed twice before executing UI tests with `Timed out while enabling automation mode`.

- First 9 August device result: unavailable at its recorded local path; no pass is claimed and the missing artefact is not linked.
- [Retry device result](</Users/tommurton/Library/Developer/Xcode/DerivedData/Ringbloom-ekhndzksekjkwghedtgicyqvimkg/Logs/Test/Test-Ringbloom-2026.08.09_21-25-06-+0100.xcresult>): retained failure evidence.

The earlier physical pass remains historical evidence but does not close the current device-verification limitation.

## Historical App Store Connect snapshot

The following state was read back on 9 August 2026. It describes the superseded build-5 draft, not a current-source candidate.

| Item | Historical state |
|---|---|
| App ID | `6789952808` |
| Bundle ID | `com.tommurton.ringbloom` |
| Live version | 1.1, Ready for Sale |
| Version 1.2 | `READY_FOR_REVIEW`, version ID `dc4c2b64-9b29-4eee-a25a-8becea261167` |
| Draft submission | `30e4396e-5bae-473d-8212-b85ca0c7663b`, `READY_FOR_REVIEW` |
| Attached binary | Superseded build 5, build ID `e0a557aa-d751-4154-af58-b197c8e3e698` |
| IAP | `6799735184`, non-consumable, `READY_TO_SUBMIT` |
| Product ID | `com.tommurton.ringbloom.flower_show` |
| IAP price | £2.99 GBP base territory; USA price read back as $2.99 |
| App price | Unchanged; the live listing remained £1.99 / $1.99 |
| Final submit control | “Submit for Review” was visible but was not clicked |

Important ASC history: while re-attaching the IAP in the browser, an interaction unintentionally submitted the earlier draft `6429389d-6246-4fed-b9da-8bc8909241d7`. It was cancelled immediately. ASC records that historical submission as `COMPLETE` with a submitted date, and the version is now `DEVELOPER_REJECTED`; no review is active. The fresh submission above was then created and verified to contain only the intended two items. No price change or production release was performed.

## Current App Store Connect snapshot — build 6

The 10 August API read-back records version 1.2 `READY_FOR_REVIEW` with build 6 attached, draft `30e4396e-5bae-473d-8212-b85ca0c7663b` still `READY_FOR_REVIEW`, and exactly two `READY_FOR_REVIEW` draft items. An independent authenticated Edge read-back then verified one Ready for Review draft with `Items Ready to Submit (2)`: (1) `iOS App 1.2`, showing `1.2 (6)` and build ID `a3434f64-3bf5-484a-9f6d-6daf0a0a3b92`; and (2) `Flower Show – Full Unlock`, identified as an In-App Purchase and linked to IAP `6799735184`. Manual release was selected, Save was disabled and `Submit for Review` remained present and untouched. The verification tab was closed without mutation.

The [IAP read-back](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/readback/iap-after-attach.json>) is unchanged: ID `6799735184`, product `com.tommurton.ringbloom.flower_show`, non-consumable, `READY_TO_SUBMIT`; [pricing](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/readback/iap-pricing-after-attach.json>) remains £2.99 GBP. No App Review submission, production release, price change or build-5 deletion occurred.

The validators are preserved rather than normalised away. The [initial TestFlight validation](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/readback/validate-testflight.json>) correctly flagged missing “What to Test” notes. Concise en-GB notes were then added to build 6; the [independent note read-back](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/readback/test-notes-en-GB-readback.json>) contains the expected test scope and the [final TestFlight validation](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/readback/validate-testflight-after-notes.json>) reports zero errors, warnings, information items or blockers. [Canonical version validation](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/readback/validate-version.json>) retains the CLI's contradictory `READY_FOR_REVIEW`/“must be editable” error, treats the IAP's expected `READY_TO_SUBMIT` draft state as a limitation, and cannot verify App Privacy through the public API. The draft was not cancelled or mutated to work around those diagnostics.

## Remaining human/release gate

1. Complete any still-required physical-device/assistive-technology suite; the historical physical UI automation limitation remains open.
2. Exercise real Apple sandbox/TestFlight purchase, Restore Purchases and revocation paths on build 6.
3. Tom verifies App Privacy, then submits the already verified two-item draft for App Review only when satisfied. After approval, Tom changes the app price to Free and releases manually.

No App Review submission, production release, price change, credential change or build-5 deletion was performed as part of this work.

The installed iPhoneOS 26.5 SDK does not expose `AppTransaction.revocationDate`; revocation is checked on StoreKit `Transaction` and through current entitlements and transaction updates.
