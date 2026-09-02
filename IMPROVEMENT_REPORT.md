# Ringbloom — Round 2 Improvement Report

Date: 12 July 2026  
App Store Connect app: `6789952808`  
Version: `1.0`  
Final build: `3` (`8cc214e4-0dca-496f-bba1-59e4bf4effd6`)  
Final staging state: `READY_FOR_REVIEW`  
Final submission performed: **No**

## Outcome

Round 2 changed the actual game, not only its documentation. The improved source was tested, archived, exported, uploaded, processed by Apple as `VALID`, attached to version 1.0, and placed in a fresh Ready for Review draft. The final Submit for Review operation remains intentionally untouched for the human operator.

## What changed in the game

| Area | Round 1 | Round 2 |
|---|---|---|
| Turn readability | Petals appeared to swap; refill obscured the solved state | The selected ring visibly rotates 45°, the aligned spoke dwells and glows, then bloom/refill/score resolve in causal order |
| Input | Repeated taps could queue turns; swipe direction ignored where the gesture occurred | Turn input is locked during resolution; swipes choose a ring by radius and direction by local tangential movement |
| First session | Static explanation before play | Garden 1 highlights a guaranteed live first bloom on the real board without spending a hint |
| Help | No contextual recovery | Three optional hints per garden identify both ring and direction without playing the move |
| Mastery | Score and simultaneous-bloom combo only | Consecutive-bloom chains, chain bonuses, remaining-move bonuses, and Seedling / Flourishing / Radiant ratings |
| Progress | Best score and highest garden | Best score, highest garden, global best chain, and Radiant garden history |
| Difficulty | Late targets rose to 10 blooms in 11 moves | Pressure now rises one axis at a time and retains a calmer late move budget; Garden 1 openings are deliberately readable |
| Continuity | Returning Home abandoned the current garden | Pause, Save & Home, and process relaunch preserve the exact Codable engine and random state |
| Accessibility | One long board summary and limited outcome semantics | Eight concise spoke elements, result announcements, semantic headings, focused overlays, hinted-state narration, adaptive layouts, and reduced-motion choreography |

The implemented source is concentrated in:

- `Ringbloom/Sources/GameEngine.swift` — scoring, difficulty, hints, ratings, progress, exact restoration.
- `Ringbloom/Sources/GameBoardView.swift` — real ring motion, bloom staging, gesture geometry, board semantics.
- `Ringbloom/Sources/ContentView.swift` — playable onboarding, turn choreography, pause/resume, outcome UI, accessibility, deterministic store scenes.

## Verification evidence

- Final Swift Testing run: **36 declared tests, 86 parameterized invocations, 0 failures, 0 skips**.
- Coverage includes chain scoring/reset, hint limits, all garden ratings, completion bonuses, Codable engine continuity, legacy progress decoding, exact production restoration, 32 Garden 1 opening seeds, 20 representative completion paths, cardinal tangential swipes, radius selection, and radial/short gesture rejection.
- Real simulator play confirmed the solved spoke remains visible during the bloom dwell before refill (`screenshots/r2-work-bloom-dwell.png`).
- A real pause → Save & Home → terminate → relaunch → Resume pass preserved score `350`, moves `10`, chain `2`, blooms `3/5`, one remaining hint, the selected ring, and every petal.
- Accessibility Extra Extra Extra Large plus Increased Contrast kept all Home/gameplay values readable and every control reachable through scrolling.
- Reduce Motion took the non-sweeping resolution path and completed a normal turn.
- Final release archive and export both report version `1.0`, build `3`.
- Apple processed the uploaded build as `VALID`, non-expired, and encryption-exempt.

## Store presentation

- Subtitle changed from implementation provenance to player value: **“Rotate Rings. Bloom Trios.”**
- Description now explains staged turns, playable onboarding, hints, chains, ratings, exact resume, accessibility, offline premium positioning, and the required two-session AI provenance.
- Promotional text and keywords were refreshed and validated with zero metadata errors or warnings.
- Two fully current screenshot sets are live:
  - Five 1320×2868 screenshots for the modern large-iPhone slot.
  - Five 1284×2778 screenshots for the 6.5-inch slot.
- Both sets are gameplay-first and show rotation, a contextual hint, a chain-2 score, a Radiant completion, and the paid/offline home proposition.
- Every screenshot reports `COMPLETE` in App Store Connect. The stale Round 1 screenshots were removed.

## App Store Connect handoff

- Build 3 is attached to version 1.0.
- Strict validation immediately before staging: **0 errors, 0 warnings, 0 blockers**.
- Review submission: `452f1a81-ade8-45d1-bfba-3e8493502ef0`.
- Version, review submission, and review status all report `READY_FOR_REVIEW`.
- ASC’s public API cannot independently verify the already-published App Privacy page; this remains an informational API limitation, not a validation blocker. The app still contains no analytics, tracking, account, third-party SDK, or gameplay networking.
- Release remains manual after approval.

## Human boundary and intervention score

No human intervention was required during Round 2: **0 nudges, 0 fixes, 0 rescues**.

The only remaining human-only action is the final **Submit for Review** decision. It was not invoked.
