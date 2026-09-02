# Final Report — Ringbloom

## The game

- **Name / genre / one-line pitch:** Ringbloom — a premium, one-thumb rotational puzzle where every turn reshapes a luminous three-ring flower.
- **Core loop:** Choose one of three rings, rotate it one notch left or right, bloom matching radial trios, and fill the garden meter before the move budget expires.

## Engine

- **Chosen:** Native SwiftUI with procedural drawing and AVFoundation. Ringbloom's deterministic, turn-based mechanic did not need a scene engine; native views produced a small 2.18 MB signed IPA, direct VoiceOver and Dynamic Type support, deterministic automation, and a low-risk Apple build/signing path. SpriteKit, Godot, and Unity would have added machinery without improving this particular loop.

## What shipped

- A complete three-ring, eight-spoke puzzle with four colour-and-glyph petal types and six meaningful actions per turn.
- Bloom detection, simultaneous-bloom combos, score, moves, escalating garden targets, fair-board repair, win, loss, retry, and next-garden flow.
- A concise first-play tutorial, direct board swipes, labelled controls, persistent best score and highest garden, and deterministic test/screenshot modes isolated from normal play.
- Original generated sound effects, haptics, independent sound/haptic toggles, Reduce Motion behaviour, VoiceOver summaries, redundant non-colour glyphs, and layouts verified at Accessibility XXXL.
- Fully offline paid-upfront operation with no account, ads, IAP, subscription, tracking, or data collection.
- A signed iOS 1.0 build, three real simulator screenshots, complete en-GB metadata, support/privacy site, US $1.99 worldwide pricing, and a draft App Review submission in `READY_FOR_REVIEW`; pre-staging strict validation found zero blockers.

## Assets

- **Generated:** 5 original assets — one app icon and four sound effects.
- **First-party captures:** 3 App Store screenshots from the final simulator build.
- **Reused derivative:** 1 byte-identical support-site copy of the generated app icon.
- **Library / downloaded:** 0 / 0. Gameplay artwork is drawn procedurally. See `ASSET_LICENSES.md` for every shipped file and its rights basis.

## What I couldn't do / cut / known issues

- Version 1.0 is intentionally en-GB only, iPhone portrait only, and has no Game Center, backend, cloud save, multiplayer, IAP, subscription, music loop, authored campaign map, skins, or social sharing.
- Testing covered 20/20 automated tests plus explicit simulator win, loss, retry, and next-garden play-throughs. No physical-device or TestFlight smoke test was performed, so device haptic feel remains unverified.
- Apple's accessibility declaration is complete and truthful but remains a non-blocking draft: ASC refuses to publish iPhone accessibility declarations until the app itself is live.
- ASC shows Apple's general reminder to refresh social-media age-rating answers by 7 September 2026; Ringbloom declares no messaging, user-generated content, or social capabilities, and the pre-staging strict validation was clean.
- Once added to the draft submission, the version correctly became non-editable. Rerunning the generic pre-staging validator then reports `version.state.editable`, while ASC's review status and UI both confirm `READY_FOR_REVIEW`, “Item Ready to Submit,” and the enabled final Submit for Review action.
- No known core-loop, signing, metadata, privacy, screenshot, or submission blocker remains. Apple Review still makes the final policy decision.

## Interventions

- **Totals:** 1 nudge · 0 fixes · 0 rescues.
- The one scored nudge was a secure account-holder sign-in after Apple's cached private-web session expired; this unlocked Apple's web-only availability and App Privacy controls. Creating the app record was an expected free handoff, and the final Submit for Review tap remains with the human. See `INTERVENTION_LOG.md`.

## Self-assessment

- **Genuinely playable:** Yes. The real build was driven through scoring, a win, next-garden reset, a loss, and retry; all 20 tests pass.
- **Apple-review outlook:** Strong but never guaranteed. The product has a complete original loop, licensed assets, accessible controls, a valid processed build, published no-data privacy answers, and had 0 ASC validation blockers before being locked into its `READY_FOR_REVIEW` draft submission.
- **Autonomy score:** 9/10 — the build and release pipeline reached `READY_FOR_REVIEW` with no human fixes or rescues and one credential nudge.

## "How this was built"

Ringbloom was researched, designed, coded, tested, and prepared for App Store review by GPT-5 Codex, an AI system, in a single product session. Native SwiftUI, procedural artwork, and original generated audio power a complete offline puzzle, while a human handled Apple's required app-record creation, renewed the secure web sign-in, and will perform the final Submit for Review tap.
