# Ringbloom freemium Flower Show — production-readiness report

Original evidence date: 9 August 2026  
Evidence hygiene revision: 10 August 2026

## Verdict

Not production-ready, but the binary-identity, ASC metadata/privacy and automated physical UI gates are closed. The current source is represented by tested, exported, inspected and staged version 1.2/build 6. Remaining gates are manual assistive-technology checks, real Apple sandbox/TestFlight commerce, and Tom's final go/no-go decision on the already verified two-item draft.

**Version 1.2/build 5 is superseded.** Its 9 August archive predates later source and test changes. Build 5 is retained as historical evidence only. Version 1.2/build 6 is the current staged candidate.

The valid non-consumable product ID remains `com.tommurton.ringbloom.flower_show`.

## Current local evidence

- [Build-6 complete clean scheme](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/test/Ringbloom-build6-full.xcresult>) passed 167 logical tests / 244 executions with zero failures or skips, including 39/39 UI tests, on a brand-new no-account iPhone 17 Pro / iOS 26.5 simulator. The [runtime scan](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/test/Ringbloom-runtime-scan-summary.txt>) found zero StoreKit/account/auth/network markers across 339,027 process lines.
- [Build-6 Release clean analysis](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/release-analysis/Release-analyze.log>) succeeded. [IPA inspection](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/inspection/ipa-inspection-summary.txt>) verifies 1.2 (6), App Store distribution signing, privacy, StoreKit linkage, expected commerce implementation/copy, no hosted markers and no `.storekit`.
- The [49-file build-6 manifest](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/source/build6-source-files.sha256>) has SHA-256 `f9f30dc0905f82a867d7c159256689d25dc22ed395e18d74cf2b0f7d3427416b` and remained unchanged through upload.
- The app has an explicit DEBUG-only hosted-test composition path. Hosted `RingbloomTests` use a no-I/O client; Release and Archive builds compile only the production `StoreKitFlowerShowStoreClient` path.
- [Canonical clean no-account RingbloomTests result](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.build/tom64-prebuild-final2-20260810T064412Z/RingbloomTests.xcresult>), [full log](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.build/tom64-prebuild-final2-20260810T064412Z/RingbloomTests.log>) and [summary](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.build/tom64-prebuild-final2-20260810T064412Z/RingbloomTests-summary.json>) record 128 logical tests in 14 suites, 205 parameterised executions, zero failures and zero skips on a brand-new iOS 26.5 iPhone 17 Pro simulator. The [targeted hosted-process scan](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.build/tom64-prebuild-final2-20260810T064412Z/RingbloomTests-runtime-scan-summary.txt>) found zero StoreKit, AppTransaction, account, authentication or network-attempt markers.
- The focused composition test is `FlowerShowStoreClientCompositionTests.hostedTestCompositionIsExplicitAndDebugOnly`.
- [Source-matched complete UI target](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.build/tom61-ui-full-current-large-source-frozen.xcresult>) passed all 39 `RingbloomUITests` with zero failures or skips on iPhone 17 Pro / iOS 26.5 simulator.
- [Source-matched compact/layout matrix](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.build/tom61-ui-compact-layout-final.xcresult>) passed 5/5 with zero failures or skips on iPhone 13 mini / iOS 26.2 simulator. The full automated and pending manual mapping, including preserved red/aborted diagnostic bundles, is in [the Flower Show UI/accessibility matrix](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/FLOWER_SHOW_UI_ACCESSIBILITY_VERIFICATION_MATRIX.md>).
- [Release clean analysis](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.build/tom64-prebuild-final2-20260810T064412Z/Release-analyze.log>) succeeded. The [Release static inspection](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.build/tom64-prebuild-final2-20260810T064412Z/Release-static-summary.txt>) found production `StoreKitFlowerShowStoreClient` symbols and StoreKit linkage for both simulator architectures, no DEBUG/hosted-test markers and no packaged `.storekit`. This inspected local product remains version 1.2/build 5 and is not a release candidate.
- The [49-file frozen-source manifest](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.build/tom64-prebuild-final2-20260810T064412Z/source-files.sha256>) has SHA-256 `d22c4d5cfc8fd387f7caf4ac4bf99d07c2dfa2d4498087b0666b0b0a2949ae5d` and was unchanged after all checks.
- Check-only default style tools do not pass this unconfigured repository: [SwiftFormat reported 488 findings](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.build/tom64-prebuild-final2-20260810T064412Z/SwiftFormat.json>) across 16 of 27 files and [SwiftLint `--strict` reported 271 findings](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.build/tom64-prebuild-final2-20260810T064412Z/SwiftLint.json>). These are pre-existing default-policy style findings; no source was changed and no clean lint pass is claimed.
- Screenshot capture now requires `--app`, `--version` and `--build`; the script rejects a 1.2/build-5 app when build 6 is requested. Its default output is candidate-specific, so the existing App Store screenshots are not overwritten.
- [TOM-65 build-6 physical/accessibility evidence](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/TOM65_BUILD6_PHYSICAL_ACCESSIBILITY_EVIDENCE_2026-08-10.md>) records the final source-matched physical run: 128 logical Swift tests / 205 executions and all 39 UI tests passed on the wired iPhone SE / iOS 26.6. The final helper installed an Apple Development test product, so this closes automated physical UI coverage but does not prove the uploaded TestFlight binary hash. The earlier automation-mode failures and the nine-test harness diagnostic run remain preserved. Manual TestFlight commerce and assistive-technology checks remain open.

## Historical automated evidence

- [Swift test result](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.build/freemium-fix/Logs/Test/Test-Ringbloom-2026.08.09_21-21-51-+0100.xcresult>): 72 tests in the 12 named suites recorded in `FREEMIUM_FLOWER_SHOW_IMPLEMENTATION_REPORT.md`.
- [UI batch 1](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.build/freemium-fix/Logs/Test/Test-Ringbloom-2026.08.09_21-14-01-+0100.xcresult>): 10 named UI tests.
- [UI batch 2](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.build/freemium-fix/Logs/Test/Test-Ringbloom-2026.08.09_21-16-57-+0100.xcresult>): 11 named UI tests.
- The combined 21-test simulator run was terminated mid-run. The batch results above are the reliable historical UI evidence.

Automated behaviour-to-test mapping is recorded in `FREEMIUM_FLOWER_SHOW_IMPLEMENTATION_REPORT.md`; no “complete coverage” claim is made.

## Physical-device evidence

The two initial 10 August TOM-65 canonical-helper attempts ran on the wired iPhone SE / iOS 26.6.
Each passed 128 logical Swift tests in 14 suites / 205 parameterised executions with no failures or
skips, then failed before executing a UI test with `Timed out while enabling automation mode`. The
first authoritative marker was `PHYSICAL_IPHONE_TESTS_FAILED (xcodebuild status 75)` and its
[result bundle](</Users/tommurton/Library/Developer/Xcode/DerivedData/Ringbloom-ekhndzksekjkwghedtgicyqvimkg/Logs/Test/Test-Ringbloom-2026.08.10_09-01-50-+0100.xcresult>)
is retained. The retry marker was `PHYSICAL_IPHONE_TESTS_FAILED (xcodebuild status 65)` and its
[result bundle](</Users/tommurton/Library/Developer/Xcode/DerivedData/Ringbloom-ekhndzksekjkwghedtgicyqvimkg/Logs/Test/Test-Ringbloom-2026.08.10_09-42-35-+0100.xcresult>)
is retained. A subsequent intermediate run executed all 39 UI tests but exposed nine physical
scroll/timing harness failures; it is retained as diagnostic evidence. After the phone was left
face-up, unlocked and awake, the final source-matched helper passed all 39 UI tests and 128/128
logical Swift tests / 205 executions:

[Final physical result](</Users/tommurton/Library/Developer/Xcode/DerivedData/Ringbloom-ekhndzksekjkwghedtgicyqvimkg/Logs/Test/Test-Ringbloom-2026.08.10_11-25-37-+0100.xcresult>).

No password was entered when diagnostic collection prompted in the failed attempts.

Before the retry, Tom confirmed installing from TestFlight. Read-only device identity showed
Ringbloom 1.2 (6), TestFlight installed and a new app container, matching exact build-6 ASC
availability. CoreDevice exposed no distribution signer, TestFlight receipt, ASC UUID or installed
binary hash, so this is deliberately recorded as correlation rather than cryptographic proof. The
helper then explicitly signed and installed an Apple Development product, changing the container
again and replacing the TestFlight-correlated app. ASC beta-usage metrics remained zero at the
earlier read-back and may lag. The paired iPhone 17 Pro was locked, preventing its installed-app
read-back. The exact device, identity, passed/failed/not-exercised checklist and smallest handoff are recorded in
[the TOM-65 evidence](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/TOM65_BUILD6_PHYSICAL_ACCESSIBILITY_EVIDENCE_2026-08-10.md>).

Historical 9 August physical evidence remains superseded and does not close the current gate.

## Candidate identity

| Field | Superseded build 5 | Current build 6 |
|---|---|---|
| Archive time | 9 Aug 2026 19:43:22 BST | 10 Aug 2026 08:24:30–08:25:04 BST; [archive](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/archive/Ringbloom-1.2-6.xcarchive>) |
| Source revision/evidence timestamp | Archive predates current source/test files | Build-6 49-file manifest SHA-256 `f9f30dc0905f82a867d7c159256689d25dc22ed395e18d74cf2b0f7d3427416b`; unchanged through upload |
| Version/build | 1.2 (5) | 1.2 (6) |
| IPA | [Historical build-5 IPA](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build5/Ringbloom-1.2-5.ipa>) | [Build-6 IPA](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/export/Ringbloom-1.2-6.ipa>) |
| IPA SHA-256 | `7035d66ca220ad155d69b549c35418a93cd03033e0094ad30cc037c1ebcece44` | `57a1ed81256ac0746975047c5e0c2d4b14a3912595be613799e2848d71d2aff4` |
| ASC build ID | `e0a557aa-d751-4154-af58-b197c8e3e698` | `a3434f64-3bf5-484a-9f6d-6daf0a0a3b92`, `VALID` |
| `.storekit` in IPA | None found | None found |
| Staged binary matches tested source/archive | No: superseded by source changes | Yes: unchanged source manifest, inspected archive/IPA identity, exact IPA hash and independent ASC read-back |

## Historical App Store Connect state

The 9 August read-back recorded version 1.2 `dc4c2b64-9b29-4eee-a25a-8becea261167`, draft `30e4396e-5bae-473d-8212-b85ca0c7663b`, superseded build 5 `e0a557aa-d751-4154-af58-b197c8e3e698`, and IAP `6799735184`. The live 1.1 listing and £1.99/$1.99 app price were unchanged. This is history, not current-candidate proof.

During browser re-attachment, the earlier draft `6429389d-6246-4fed-b9da-8bc8909241d7` was unintentionally submitted and cancelled immediately. ASC history records it as `COMPLETE` with a submitted date and the version as `DEVELOPER_REJECTED`; no review is active. The fresh draft above was then created and verified. This history is recorded here rather than represented as an absent submission.

## Current App Store Connect state

[Build read-back](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/readback/build6-by-id.json>) is `VALID`; [version read-back](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/readback/version-after-attach.json>) shows build 6 attached to 1.2; the [internal Test-group relationship](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/readback/build6-test-group-link.json>) is present. The IAP remains ID `6799735184`, non-consumable, `READY_TO_SUBMIT`, £2.99 GBP.

The draft remains `READY_FOR_REVIEW` with exactly two `READY_FOR_REVIEW` items. An independent authenticated Edge read-back verified `Items Ready to Submit (2)` contains exactly `iOS App 1.2` showing `1.2 (6)` and `Flower Show – Full Unlock` linking IAP `6799735184`. Manual release was selected, Save was disabled, and `Submit for Review` was not clicked. The initial TestFlight validator correctly identified missing “What to Test” notes; approved en-GB notes were added and [read back](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/readback/test-notes-en-GB-readback.json>), after which the [TestFlight validator](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/readback/validate-testflight-after-notes.json>) reported zero errors, warnings, information items or blockers. TOM-65 read-back confirms the build is `VALID` and `IN_BETA_TESTING`; the internal all-builds `Test` group links build 6 and contains Tom's installed tester account. Version metadata, full review notes and both complete seven-image iPhone screenshot sets remain present. Authenticated App Privacy read-back shows the published `Data Not Collected` declaration and policy URL. IAP `6799735184` retains the exact product ID, two localisations, £2.99 pricing, review notes and complete `SOURCE` review screenshot. Canonical version validation retains its known contradictory `READY_FOR_REVIEW` state diagnostic, while the IAP remains in its expected API `READY_TO_SUBMIT` draft state (`Ready for Review` in the UI). No App Review submission is active, and the app price/release state is unchanged.

## Open gates

1. Reinstall TestFlight build 6 on the unlocked test iPhone because the canonical helper replaced it, then complete the pending physical assistive-technology matrix.
2. Decide whether the unconfigured default SwiftFormat/SwiftLint findings require a baseline or project policy; no automatic formatting was applied.
3. Exercise real sandbox/TestFlight purchase, restore and revocation on build 6.
4. Tom makes the final go/no-go decision and, only after the physical/manual/commerce gates close, submits the already verified two-item draft. After approval, Tom changes the app price to Free and releases manually.

No App Review submission, production price change or production release was performed as part of this work.

The installed iPhoneOS 26.5 SDK does not expose `AppTransaction.revocationDate`; the implementation uses verified StoreKit `Transaction` revocation plus current entitlements and transaction updates.
