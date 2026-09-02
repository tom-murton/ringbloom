# Ringbloom 1.1 (3) — TestFlight release record

## What to Test

Build 3 improves Bindweed clarity without changing the mechanic. The briefing now says every tangled stem must be cleared to win and that spreading adds another stem. Spreading produces a prominent warning, warning haptic and animated new stem; reaching the bloom target with Bindweed remaining shows a persistent instruction to clear it.

Flower Show remains a focused 30-class challenge campaign followed by the endless Champion Circuit. Every class briefing clearly shows what changed, new rules arrive at Classes 1, 6, 11 and 16, and every fifth class is a Rosette Class. Later classes combine the rules under tighter move limits. Live objective feedback makes chains, Bindweed, Twin Bloom and Harmony progress explicit.

Flower Show has one Hint and one exact Undo per class. Garden remains unchanged with three Hints. Existing beta Flower Show progress resets once so testers receive the redesigned sequence; Garden progress is preserved.

Please focus on:

- The clearer home screen, especially Flower Show's 0/10 unlock progress.
- Flower Show unlocking immediately after the tenth Garden win.
- Each class briefing clearly identifying what is new or harder.
- The four rule introductions at Classes 1, 6, 11 and 16.
- Rosette Classes every fifth class and the Class 30 Grand Champion transition.
- Class 11 explaining that all Bindweed must be cleared to win.
- Bindweed visibly adding another required stem after three uncleared turns.
- The persistent instruction after the bloom target is met with Bindweed remaining.
- Later multi-Bindweed classes announcing every spread, even after an earlier stem was cleared.
- The single Hint and exact Undo available in every Flower Show class.
- Saving, relaunching and resuming either mode without losing state.
- Whether the difficulty rises gradually and remains enjoyable through later classes.
- The App Store review request appearing only after a completed Garden, never during play.

## Distribution targets

- Internal group: `Test` — in beta testing
- External group: `Safak` — submitted to TestFlight Beta App Review
- External build state: `WAITING_FOR_BETA_REVIEW`
- Beta review submission state: `WAITING_FOR_REVIEW`
- Auto-notify: enabled
- Superseded 1.1 (2) build: expired after its in-progress beta review blocked build 3's submission
- Superseded 1.1 (1) build: expired after it blocked build 2's beta review submission

## Validation

- Normal simulator: 75 Swift tests and 9 UI tests passed
- Release archive, App Store export and strict signature verification: passed
- Attached iPhone: 75 Swift tests and 9 UI tests passed; `PHYSICAL_IPHONE_TESTS_PASSED`
- Flower Show balance simulation: 380 objective-aware completions across the campaign and Champion Circuit

## Build identity

- App Store Connect app: `6789952808`
- App Store Connect build: `937f4cdf-a063-4d60-986b-23b86e1a1de5`
- Marketing version: `1.1`
- Build number: `3`
- Bundle identifier: `com.tommurton.ringbloom`
- IPA SHA-256: `af9c867bc62bf290935c1f3a0e69fb97d948dbb40b7d4295261a064bf8459a24`
