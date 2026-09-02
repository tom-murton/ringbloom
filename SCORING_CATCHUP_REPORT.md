# Ringbloom — scoring catch-up report

Date: 22 July 2026  
Website repository checked: `/Users/tommurton/GitHub/personal-cv`

## Sources checked

- Round 1: `INTERVENTION_LOG.md`, `DECISION_LOG.md`, `FINAL_REPORT.md`, `GAME_DESIGN.md`, and the original Codex session metadata.
- Round 2: `INTERVENTION_LOG_R2.md`, `DECISION_LOG_R2.md`, `IMPROVEMENT_REPORT.md`, and the original Codex session metadata.
- Round 3: `INTERVENTION_LOG_R3.md`.
- Live store state: App Store Connect app `6789952808`, current release status, full review history, current US/UK pricing, and the public UK/US App Store records, checked on 22 July 2026.
- Website history: the two commits that introduced the benchmark and later corrected Brinkball. Neither contains a Ringbloom per-game review; the current page still deliberately renders the write-up-pending fallback.

## Verified and corrected

| Field | Previously published | Verified value | Evidence |
|---|---|---|---|
| `slug` / `name` | `ringbloom` / Ringbloom | unchanged | Run artefacts and live App Store record |
| `model` | GPT-5 Codex | **GPT-5.6 Sol Ultra** | Both root Codex sessions record model `gpt-5.6-sol` and reasoning effort `ultra`; the canonical run folder uses the same name |
| `harness` | Codex | unchanged | Original session metadata identifies Codex Desktop |
| `engine` | unset | **Native SwiftUI** | `FINAL_REPORT.md` and `DECISION_LOG.md`; AVFoundation supplies audio but is not the game engine |
| `status` | shipped | unchanged | App Store Connect reports version 1.0 as `READY_FOR_DISTRIBUTION`; the public store record is live |
| `statusLabel` | Shipped | **Live on the App Store** | Current live store state |
| `date` | July 2026 | unchanged | The benchmark entry was committed on 22 July 2026 |
| `autonomy` | 0 nudges, 0 fixes, 0 rescues | **1 nudge, 0 fixes, 0 rescues** | One scored row in `INTERVENTION_LOG.md`; the computed build-autonomy score changes from 100 to **95/100** |
| `improveScore` | unset | **0 nudges, 0 fixes, 0 rescues** | Round 2 exists and its scored-interventions table has no rows |
| `articleScore` | unset | **2 nudges, 0 fixes, 0 rescues** | Two scored rows in `INTERVENTION_LOG_R3.md`; the second records the operator correcting the missing production write-up and deployment target |
| `appleReview` | unset | **approved first pass** | The current completed review item is `APPROVED`; the history contains no `REJECTED` item. The earlier item was removed by the developer and is not an Apple rejection |
| `appStoreUrl` | unset | **UK App Store listing added** | Current public App Store record |
| `price` | unset | **£1.99 / US $1.99** | Current App Store Connect prices and public UK/US listings |

The summary was changed only because it contradicted the verified facts: the model name was wrong, round 1 was not intervention-free, and round 2 genuinely happened.

## Deliberately left unset

- `buildStats`: the decision logs contain wall-clock timestamps, but round 1 includes an 8-hour 52-minute wait for the app record and neither round records a defensible active-build duration or model cost. No estimate was substituted.
- `quality`: not self-scored, as required.
- `reception`: not self-scored. The public listing currently shows no ratings, but that is not a substitute for the benchmark's independently maintained reception field.
- `review`: the initial catch-up incorrectly left this unset despite Round 3 requiring the model to publish its own write-up. The completed, log-grounded story and five real game screenshots were added after the operator corrected that interpretation.

## Verification

- `npm run build`: passed with Vite 5.4.21. The existing stale Browserslist-data and circular-chunk warnings remain non-fatal.
- Local scoreboard: verified after the scoring update. Ringbloom renders at 95/100 for Round 1, with Round 2 and Round 3 marked complete.
- Local `/projects/ship-a-game/ringbloom`: verified at 1280 px desktop and 390 px mobile. The full 29-paragraph story, seven sections, five real screenshots, 95/100 Round 1 score, 100/100 Round 2 score, 90/100 Round 3 score, Apple outcome, price and App Store link render correctly. All lazy-loaded screenshots were confirmed loaded after scrolling. There were no console errors, error overlay or horizontal overflow.
- Deployment: commit `5c30b3e` (`Publish Ringbloom benchmark story`) was pushed to `tom-murton/personal-cv` on `main`. Vercel production deployment `dpl_3xEGvkU2rHC2tHhTxCQdWo9dep3e` reached `READY` and its build completed in 19 seconds. The live `https://www.tommurton.com/projects/ship-a-game/ringbloom` route was rechecked at 1280 px and 390 px: the fallback is absent, all seven sections and five screenshots render, all lazy-loaded images resolve, the App Store link is correct, and there are no console errors, error overlays or horizontal overflow.
