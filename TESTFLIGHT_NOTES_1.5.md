# Ringbloom 1.5 (9) — TestFlight preparation

## What to test

Version 1.5 adds privacy-conscious PostHog product analytics. The game, progress model and purchase entitlement are unchanged from the live 1.4 release.

Please focus on:

- Launching, backgrounding and reopening without any visible delay or error.
- Every Home control, the tutorial, Class Book and both game modes behaving exactly as before.
- Garden and Flower Show turns, hints, undo, pause, save, resume, win and loss paths.
- Opening the purchase screen from Home, after Class 5 and from a locked Class Book tile.
- Closing or choosing **Keep Playing Free** without losing progress.
- Product loading, purchase cancellation, successful sandbox purchase and **Restore Purchases**.
- Full access persisting after relaunch.
- No App Tracking Transparency prompt and no new permission prompt.

## Analytics verification

- Confirm `screen_viewed`, `button_tapped`, gameplay and paywall events arrive in PostHog project `261844` with `build_configuration = release`, `app_version = 1.5` and `build_number = 9`.
- Confirm the **Ringbloom Product & Paywall** dashboard populates after the relevant actions.
- Confirm no `$screen`, `$autocapture`, session replay, `$identify` or `$exception` event is produced.
- Confirm outgoing events include `$geoip_disable = true` and new events do not gain GeoIP-derived location fields.
- Confirm PostHog receives no StoreKit transaction ID, typed text or game-board contents.

## Distribution state

Uploaded to App Store Connect on 31 August 2026 and verified after Apple processing:

- Version: `1.5`
- Build: `9`
- Build ID: `ca609dad-91a2-4f54-b6f4-535f6e1faeea`
- Processing state: `VALID`
- Minimum iOS: `17.0`
- Export compliance: no non-exempt encryption
- IPA SHA-256: `c7fe0372ca216f211b0de264b47eefa485d98e7e3dcec36517079c09c3cd7a0f`

The build is attached to App Store version 1.5 in **Prepare for Submission**. It has not been submitted for App Review, released to the App Store or assigned to an external TestFlight group.
