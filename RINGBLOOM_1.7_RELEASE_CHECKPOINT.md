# Ringbloom 1.7 (13) release checkpoint

Status on 10 October 2026: **build 13 attached to App Store version 1.7 in Prepare for Submission; not submitted for App Review or released**.

## Change since live 1.6 (12)

Gameplay board layout only (TOM-715, PR #6): the board scales to the space left by the header and controls so the ring selector and Turn buttons stay on screen in late Flower Show Classes on small and standard iPhones, and objective rows are more compact on shorter phones. No campaign content, progression, purchase or analytics change.

## Build

- Version `1.7`, build `13` (`project.yml`); previous highest uploaded build was 12.
- App Store Connect build ID: `56087afe-69a7-4d63-94b4-d32181548d41`, processing state `VALID`, minimum iOS 17.0.
- Export compliance: `ITSAppUsesNonExemptEncryption = false`; App Store Connect reports `usesNonExemptEncryption = false`, as for build 12.
- IPA: `.asc/artifacts/export-1.7-13/Ringbloom.ipa` (ignored locally), 5,946,805 bytes, SHA-256 `4e73f4e962aa3751fd637e62e4f76610149ff136efabca1837c1d1fe2ddfc91d`.
- Signed by Apple Distribution: Tom Murton (5R8P82H779) with profile "Ringbloom App Store 2026"; `codesign --verify --deep --strict` passed; privacy manifests present for the app, PostHog, FeedbackKit and AppsFlyer.
- Signing note: automatic-signing archive hung on a keychain codesign prompt, so the archive was made unsigned (`CODE_SIGNING_ALLOWED=NO`) and signed at export with `ExportOptions.plist`.

## Verification

- Full `xcodebuild test` on iPhone 17 Pro (iOS 27.0 simulator): 217 Swift Testing tests passed; 57 XCTest UI tests executed, 0 failures, 2 skipped by design (explicit analytics ingestion). xcresult totals: 274 tests, 271 passed, 3 skipped, 0 failed. No flaky retry was needed.
- `Tools/certify-flower-show.sh` not run: campaign content unchanged.
- `asc validate`: 0 errors, 0 warnings, 0 blocking. Infos: no iPad screenshot set, release type is manual, App Privacy publication state is not verifiable through the API.

## Store text

en-GB What's New: "Late Flower Show Classes now fit on iPhone screens, with the ring selector and Turn buttons kept in view. Objective lists are also more compact on smaller iPhones." Screenshots, previews, promotional text, subtitle and keywords were left unchanged.

## Owner gates

Review version 1.7 in App Store Connect and submit for App Review manually.
