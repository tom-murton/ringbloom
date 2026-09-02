# Flower Show V3 — App Store Connect Preparation Report

Date: 1 August 2026  
App: Ringbloom  
App Store Connect app ID: `6789952808`  
Bundle ID: `com.tommurton.ringbloom`  
Prepared version: `1.1` (`4`)

## Verdict

**READY FOR TOM TO SUBMIT TO APP REVIEW.**

Flower Show V3 build 4 is valid and actively available in both Internal and External TestFlight. App Store version 1.1 is staged in `PREPARE_FOR_SUBMISSION` with build 4 attached, complete metadata, complete review information and two complete seven-image iPhone screenshot sets. No production App Store review submission has been created.

## Test evidence

- iPhone 17 Pro simulator, iOS 26.5: 71/71 tests passed, including UI tests.
- iPhone 13 mini simulator, iOS 26.2: 71/71 tests passed, including UI tests.
- Generic Release simulator build: passed.
- Signed physical test iPhone: `PHYSICAL_IPHONE_TESTS_PASSED`; 56 Swift Testing unit/integration tests in 9 suites passed.
- The first physical run exposed three migration tests that incorrectly depended on Mac source paths. Fixtures now resolve from the signed test bundle, and the corrected tests pass on simulator and iPhone.
- The physical UI runner could not enable automation mode on the test handset and timed out. This does not affect the signed app or the physical unit/integration result, but hands-on physical UI testing remains the sensible final check before production submission.
- Flower Show catalogue certification: 166 valid scenarios.
- Independent route validation: 146/146 fixtures passed with 292 route witnesses.

## TestFlight destination state

Build ID: `88ee0a35-5102-4652-9bb7-3a2d9f4a2711`

- Processing state: `VALID`.
- Encryption declaration: `usesNonExemptEncryption = false`.
- Internal group `Test`: build 4 present; group receives all builds.
- External group `Safak`: build 4 present.
- Apple external beta review: `APPROVED`.
- Internal state: `IN_BETA_TESTING`.
- External state: `IN_BETA_TESTING`.
- Automatic tester notification: enabled.
- English (UK) “What to Test” notes: present and tailored to V3.
- TestFlight validation: 0 errors, 0 warnings, 0 blockers.

The previous build 3 was already internal and externally approved. Build 4 is the new Flower Show V3 binary and has replaced it as the latest test build.

## App Store version 1.1

Version ID: `66c465cf-694e-4d77-a8ee-3b5afa71d59c`

- State: `PREPARE_FOR_SUBMISSION`.
- App Store review submission: not created.
- Build 4: attached.
- Release type: `MANUAL` so approval will not release the app automatically.
- Copyright: `2026 Tom Murton`.
- Age rating declaration: present and complete.
- App Review contact: present.
- Demo account: not required.
- App Review notes: updated with the Flower Show entry path, controls, Class objectives, Class Book, Champion Circuit and offline/privacy behaviour.

## Store metadata

English (UK) metadata is present in ASC and mirrored locally in `metadata/version/1.1/en-GB.json`:

- Description: 2,638 characters.
- Keywords: 98/100 characters.
- Promotional text: 116/170 characters.
- What’s New: 857 characters.
- Marketing URL: present.
- Support URL: present.

The copy leads with the 30-Class Flower Show campaign and Champion Circuit, explains the new rules and progression, retains Garden positioning, and keeps the AI-development disclosure explicit.

## Screenshots

The old Garden-only screenshot sets on version 1.1 were replaced.

- 6.5-inch set: 7/7 uploaded, all `COMPLETE`, 1242 × 2688.
- 6.7-inch set: 7/7 uploaded, all `COMPLETE`, 1320 × 2868.
- The in-app captures remain visually unaltered; the treatment adds branded gradients, ambient floral geometry and concise campaign-led wording around them.

Local review contact sheet: `screenshots/flower-show-v3/review/flower-show-v3-contact-sheet.png`.

## Final ASC validation

Canonical App Store validation:

- Errors: 0.
- Warnings: 0.
- Blocking issues: 0.

App Review diagnostics:

- Review detail configured: yes.
- Review state: `NOT_SUBMITTED`.
- Result: “No submission blockers detected. Submit the version when ready.”

Two informational advisories remain:

1. Release is deliberately manual.
2. Apple’s public App Store Connect API cannot verify the App Privacy page’s published state. The live 1.0 app already uses the same no-data position, but Tom should visually confirm App Privacy in ASC as part of the retained final submission step.

## Tom’s remaining action

In App Store Connect, review version 1.1, confirm the App Privacy page and any final AI-content declaration presented by Apple, then press **Submit for Review**. No archive, upload, build selection, TestFlight distribution, metadata entry or screenshot work remains.

Before production submission, complete the planned hands-on run on the attached iPhone, particularly the home-to-Flower-Show path, Class Book, Hint/Undo disclosures, Bindweed preview, Dynamic Type, VoiceOver and Garden regression.
