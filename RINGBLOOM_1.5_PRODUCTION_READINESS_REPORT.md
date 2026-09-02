# Ringbloom 1.5 production readiness

Status on 31 August 2026: **technically staged; TestFlight acceptance remains; not submitted or released**.

## Release candidate

- App Store version: `1.5`
- Build number: `9`
- Bundle ID: `com.tommurton.ringbloom`
- Minimum iOS: `17.0`
- App Store Connect build ID: `ca609dad-91a2-4f54-b6f4-535f6e1faeea`
- App Store Connect processing state: `VALID`
- App Store version state: `PREPARE_FOR_SUBMISSION`
- Attached build: `9`
- IPA: `.asc/artifacts/Ringbloom-1.5-9.ipa`
- IPA size: 5.2 MB on disk (5,477,881 bytes uploaded)
- IPA SHA-256: `c7fe0372ca216f211b0de264b47eefa485d98e7e3dcec36517079c09c3cd7a0f`

The exported app is signed by **Apple Distribution: Tom Murton (5R8P82H779)**. `codesign --verify --deep --strict` passed, the bundle reports version 1.5 build 9, and the app plus both analytics SDKs contain privacy manifests.

## Verification evidence

- Xcode archive: passed for the Release configuration and generic iOS device.
- App Store export: passed using `ExportOptions.plist`.
- Apple processing: build 9 appeared in App Store Connect with state `VALID`.
- App Store metadata: pushed to version 1.5 and pulled back from App Store Connect to verify the updated description and What's New text.
- App Store readiness validation: 0 errors, 0 warnings and 0 blockers. App Privacy publication state is not exposed by Apple's public API, so it was subsequently verified in the signed-in App Store Connect web UI.
- App Store Privacy: the published answers already declare Product Interaction for Analytics, linked to the device/installation identifier and not used for tracking. No change or republication was required for PostHog.
- Canonical privacy policy: deployed from `weevolve-site` commit `73151b4` and verified live at `https://weevolve.app/ringbloom/privacy/` with the 31 August effective date and PostHog disclosure.
- Local metadata validation: 0 errors and 0 warnings.
- Unit tests: all 139 tests passed.
- Complete test result: 180 logical tests passed; one UI test runner process was terminated by the simulator rather than failing an assertion.
- Isolated rerun of the affected UI scenario: passed in 18.97 seconds with 0 failures.

The transient simulator termination is retained in `.asc/artifacts/Ringbloom-1.5-tests.xcresult`; the clean targeted rerun is retained in `.asc/artifacts/Ringbloom-1.5-failed-test-rerun.xcresult`.

## Analytics readiness

- PostHog iOS SDK 3.59.3 is integrated with automatic screen/element capture, session replay, surveys and identification disabled.
- Every outgoing PostHog event is amended with `$geoip_disable = true`.
- The live EU project previously received a normal app event end to end.
- The pinned **Ringbloom Product & Paywall** dashboard was re-read after staging and contains the five intended product and paywall views with clean names.
- AppsFlyer remains the sole attribution provider; PostHog is used only for anonymous product behaviour.

## Owner gates before App Review

1. Run the TestFlight checks in `TESTFLIGHT_NOTES_1.5.md`, including a sandbox purchase/restore and confirmation that release events arrive with `$geoip_disable = true`.
2. Review the staged 1.5 metadata and screenshots, then submit manually when satisfied.

No App Review submission or production release was performed.
