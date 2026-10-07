# Ringbloom — iOS 27 App Store creative set (October 2026)

Prepared on branch `claude/ios27-store-assets` from `origin/main` (`5c67543`), then recaptured on `claude/ios27-store-recapture` (7 Oct 2026, native iPhone 17 Pro Max captures, slot 6 added). Nothing was uploaded and nothing in App Store Connect was changed. Regenerate with `python3 Tools/compose-ios27-store-assets.py` and `python3 Tools/build-ios27-app-preview.py`.

ASC app `6789952808`, live version 1.6 (build 12), `en-GB` only. No version after 1.6 exists yet, so the upload needs a new version (see "Next version").

## What changed and why

| Live problem | Rule / reason | Fix |
|---|---|---|
| Live shot `03-purchase.png` shows "UNLOCK FOR £2.99" | Prices are prohibited in all assets | Paywall frame dropped. No new asset shows a price, "free", "unlock" or any purchase UI. |
| Raw, uncaptioned simulator captures | Captions should add to the visual | Every screenshot is now branded and captioned, using the V3 style (navy gradient, accent pill, rounded bold title, framed capture) from `Tools/compose-flower-show-v3-screenshots.py`. |
| The board (the hook) was only at position 4 | First ~3 screenshots appear in search | Position 1 is a real double bloom from one turn. Position 2 shows Garden and Flower Show side by side. Position 3 is a real Flower Show rule card. |
| "BEST 0 / GARDEN 11" inconsistency (live 1 and 6) | Consistency | The home screen is not used. All Garden captures come from one Garden 1 session at 09:41. |
| Dimmed modal at position 7 | Show the real app in use | Dropped. |
| Stale 1.3-era app preview | Use current UI | New preview cut from the 2 Oct 2026 iOS 27 recording (see Preview). |

## Screenshots (upload-ready, 6 per set)

Source for every screen: first-party captures from one session on a dedicated iPhone 17 Pro Max simulator (iOS 27.0, en_GB, 09:41 override, full battery, Ringbloom 1.6 build 12 Debug build from `main`, native 1320x2868, no scaling). Garden screens are real Garden 1 play (`--ui-testing --seed=424242`, driven with the in-game hint and taps); the Class 1 card, Class Book and Champion Circuit screens use the app's own `--screenshot-*` launch states. Each still is a frame of an untouched Simulator recording (plain `simctl screenshot` frequently omits the Dynamic Island; recording frames always include it). The final PNGs are RGB. Provenance and licence: first-party app captures and the first-party app icon (`ASSET_LICENSES.md`); fonts are Apple's SF Rounded and SF, as in the V3 set, used for App Store promotion of an Apple-platform app. The six source stills are in `source/`.

| # | File | Source | Caption | Purpose |
|---|---|---|---|---|
| 1 | `01-turn-a-ring-bloom-the-garden.png` | `source/garden1-combo-bloom.png`: Garden 1, third hinted move, double bloom mid-glow | TURN A RING. BLOOM THE GARDEN. / One thumb. Three rings. | The hook: two blooms from one turn, real HUD. Works alone in search. |
| 2 | `02-two-ways-to-play.png` | `source/garden1-single-bloom.png` (first bloom opening) + `source/class1-card.png` | TWO WAYS TO PLAY / Settle in, or take on a Class. Labels: GARDEN "Endless and calm", FLOWER SHOW "Judged Classes". | Garden vs Flower Show. Wording follows the in-app mode descriptions. |
| 3 | `03-a-new-rule-to-master.png` | `source/class1-card.png` | A NEW RULE TO MASTER / Special rules. Fresh objectives. | Special rules (Ring Harmony). |
| 4 | `04-thirty-classes-to-master.png` | `source/class-book.png` | THIRTY CLASSES TO MASTER / Replay to improve your rating. | Class Book. The "Full Show required" rows state no price. |
| 5 | `05-stuck-take-a-hint.png` | `source/garden1-hint.png`: fresh Garden 1, hint on the Inner ring | STUCK? TAKE A HINT / Hints show which ring to turn. | Garden support feature, shown in the real hint state. |
| 6 | `06-the-champion-circuit.png` | `source/champion-circuit.png`: Circuit Class 31, fresh | THE CHAMPION CIRCUIT / Keep going beyond Class 30. | Champion Circuit, as a player who owns the full Show. |

Upload targets (`en-GB`, ascending order = filename order):
- `screenshots/APP_IPHONE_67-1320x2868/en-GB/` — 6.7" / 6.9" slot (1320x2868). ASC may label this set `APP_IPHONE_67` or 6.9" in the new UI; 1320x2868 is the accepted size.
- `screenshots/APP_IPHONE_65-1242x2688/en-GB/` — 6.5" slot (1242x2688).
- No iPad set (the app does not ship one).

Both sets replace the whole live set (7 each).


### Slot 6: Champion Circuit, and how it stays honest about access
The Circuit sits behind the permanent purchase, so the screen is captured as a player who has it: launch states `--screenshot-flower-show-game --flower-show-access=full-purchase --flower-show-class=31` (the app's own full-access test override; no StoreKit sandbox was needed and nothing was bought). The on-screen state is Circuit Class 31, a fresh attempt: "0/8 blooms · 10 moves left · Radiant possible", Ring Harmony, Twin Bloom, Prize Bouquet and the board. No price, "free" or "unlock" text appears on the screen or the caption, and the caption does not claim access is free. The caption states what the app does: the Circuit continues after Class 30.

A home-screen shot was not made: the app's preview launch states always show "BEST 0" next to "GARDEN 11" (the same inconsistency this set was meant to remove), and a fresh install shows Flower Show as "LOCKED", so no honest and attractive home state was available without changing app code.

## Header and search (creative assets)

Both use the same single idea, **"Turn a ring. Bloom the garden."**, real board from capture #1 (double bloom), the real app icon, and brand art built from the app's own palette (navy, lifted radial glow, coral/saffron/mint/sky accents, concentric rings). No generated imagery.

| File | Size | Notes |
|---|---|---|
| `creative/header-21x9.png` | 3840x1646 | 21:9 header, rebuilt from the native Pro Max frame (early glow, so the bloom stays inside the medallion). Icon, headline and board all sit inside the central ~60% (x 768–3072). The real board is the focal point at the right of centre, edge-faded into a medallion; no phone chrome, so nothing else competes. |
| `creative/search-3x2.png` | 3840x2560 | 3:2 search / Apple Games app. Real gameplay screen is large and prominent; text is the 6-word line "Turn a ring. Bloom the garden." plus the icon. |
| universal 16:9 (5244x2950) | not made | The 21:9 and 3:2 compositions differ too much for one frame to serve both. |

Upload to the Asset Library (App Store Connect product-page creative assets) for the new iOS 27 header and search slots. Check both in Apple's product page preview tool before saving: the header's headline left edge sits at x=800 and the board's right edge at about x=3070.

## App preview

`preview/ringbloom-ios27-preview-886x1920.mp4` — 16.03 s, 886x1920 (Apple's accepted portrait size for the iPhone slots), 30 fps, H.264 High 4.0, 11.0 Mbps CBR, stereo AAC 48 kHz (silent track, so it works muted and meets the audio requirement), 22 MB.

- Source: the 2 Oct 2026 real Garden 1 recording (not sped up; only the original lead-in and the 2.6 s pause were already cut in the capture, and this edit trims the first 0.45 s and the result card). No UI is fabricated.
- Opens on the first bloom (glow begins about 0.15 s in), plays four real blooms, ends on the settled "2x COMBO · CHAIN 4 +700" board with a 0.7 s hold. It stops before the "Garden Complete" card, because that card carries the "Try Flower Show — 5 free classes" button (purchase wording).
- Loop: 0.25 s fade in from navy and 0.45 s fade out to the same navy.
- Captions for muted viewing: TURN A RING, FOLLOW A HINT, CHAIN BLOOMS (the hint states appear on screen at those times).
- `preview/poster-frame.png` (886x1920, RGB): the combo bloom at **15.00 s** in the clip. Set it as the poster frame in ASC.
- Not verified: Apple's own uploader. The ASC spec check was against the published 6.5" page (886x1920, 15–30 s, ≤30 fps, High 4.0 H.264, 10–12 Mbps, AAC 256 kbps). The 6.9" slot should accept the same 886x1920 file or scale it.

## Checks done

- Every PNG (screenshots, creative, poster, contact sheet) verified programmatically as RGB with no alpha at the exact size above (`PIL`). Video verified with `ffprobe`.
- Looked at every output image (contact sheet and individual full-size views of the hero screenshot, two-ways screenshot, header, search, poster, and a 7-frame strip of the preview).
- Text scan: no prices, "free", "unlock", "no subscription", URLs, © symbols, awards, or other-platform logos in any caption. The only in-capture words that could read as purchase wording are the Class Book's "Full Show required" row labels, which are real UI and state no price.
- 4+ suitable: puzzle, no violence.
- Status bar reads 09:41 on every capture, with the same charging battery, 4 cellular bars and 3 Wi-Fi bars (one session, one simulator, override applied).
- UI tests run on the iPhone 17 Pro Max simulator (iOS 27.0), 6 executed, 0 failures: `testGrandChampionContinuesIntoChampionCircuit`, `testClassBookShowsStagesRatingsAndReplayableTiles`, `testEveryNewRuleAppearsAtItsIntroductionClass`, `testAppPreviewGardenCapture`, `testReducedMotionAndIncreasedContrastKeepLateClassControlsReachable`, `testHomeAndSettingsKeepFeedbackAvailable`. The full UI suite was not run; no app or test code changed.
- The last Garden stills (slides 1, 2, 5) and the header/search board are now native-size; no slide upscales a capture.

## Recapture notes (7 Oct 2026) and layout bug found

Done: Champion Circuit slot 6; native Garden stills (double bloom, single bloom, hint); native Class 1 card and Class Book; header and search rebuilt. Not done: home screen (see slot 6 note).

### Layout bug: Turn Left / Turn Right clipped on iPhone 17 Pro (app code not touched)
Reproduced. Evidence in `work/bug/` (`class30-pro-vs-promax.png` is the side-by-side; raw captures alongside).

- iPhone 17 Pro (402x874 pt), Class 30 (Ring Harmony row, Bindweed row, Prize Bouquet): the Turn Left / Turn Right buttons are laid out at y 855 to 904, below the 874 pt screen edge. Only their top 19 of 49 pt show. A tap in the visible strip still plays a move (verified: "10 moves left" became "9").
- The gameplay view is a `ScrollView` (`ContentView.swift`, `gameplayContent`), so dragging on the header scrolls the buttons into view (verified; the hint and Pause then scroll off the top). Dragging on the board does not scroll. So the controls are reachable but the first view of the screen shows them cut off, and the primary controls are not visible without scrolling.
- Cause, from code reading only: the board is sized `min(width - 32, height * 0.49)` (370 pt on the Pro), independent of how many objective rows sit above it, so Classes with three rows overflow the screen on a 874 pt tall device.
- Pro Max (440x956 pt): Class 30 fits, but the buttons end at 942 pt, inside the 34 pt home-indicator zone, so it is tight rather than clean.
- Classes sampled on the Pro (turn buttons' bottom edge in pt; screen is 874). Clipped: 20 (883), 25 (904), 27 (883), 28 (884), 29 (883), 30 (904), 31 (904), 32 (884), 35 (883), 40 (884). Fit: 1, 6, 11, 16, 24 (779 or less) and 26 (831). Other Classes were not sampled.
- The existing UI test `testReducedMotionAndIncreasedContrastKeepLateClassControlsReachable` passes because it scrolls to the control (`reveal`), so it does not catch this.
- Suggested follow-up: size the board from the remaining height after the objective rows, or pin the control row below the scroll content.

## Subtitle proposal (Tom decides; needs a new version)

Live subtitle is "Rotate Rings. Match 3 Petals", which contradicts BRAND.md (never match-three). The live description also opens with "Rotate a ring. Match three petals." and the live promotional text starts "Rotate. Match. Bloom.".

- **Recommended: "Turn rings. Bloom the garden."** (29/30 characters)
- Alternatives: "A calm ring-turning puzzle" (26), "Rotate rings. Bloom petals." (27).

The subtitle can only change with a new version. Suggested description opening to match: "Turn a ring. Bloom the garden." (replace the first line only).

## Promotional text

Now live: "Turn a ring. Bloom the garden. Relax in the endless Garden or take on judged Flower Show Classes. No ads." (105/170). `metadata/version/1.6/en-GB.json` now matches it (it still held the old "Rotate. Match. Bloom." text).

## Repo metadata drift

Compared the live 1.6 `en-GB` version and app-info localisations against `metadata/version/1.6/en-GB.json` and `metadata/app-info/en-GB.json`: identical at the time (before the promotional text was changed live; the repo copy is updated in the recapture PR). Fixed instead: `ASSET_LICENSES.md` did not record any of the current store artwork (it only listed 2026-07/08 screenshot paths that no longer exist in the repo); entries for this set are added.

## Optional ChatGPT image prompt (header background)

Not needed to ship (the header above uses no generated art). A painterly garden would add warmth. If the lead runs it, use the result only as a background behind the board; keep the real board and text crisp, and flatten to RGB.

> A wide 21:9 painterly night-garden scene in rich ink-navy, seen from slightly above, softly lit from the centre, with large simplified petals and leaves in coral red, saffron yellow, mint green and sky blue drifting around an empty dark circular clearing in the middle-right of the frame. Calm, tactile, gouache-style texture, soft glows, no text, no letters, no logos, no characters, no hands, no devices, no UI, nothing in the centre of the frame (left 40% mostly dark and quiet for a headline). 3840x1646.

## Next version

`project.yml` is at 1.6 (build 12) and matches the live version. The next release will be **1.7**; create that version in ASC (subtitle, screenshots, preview and header/search all need it or an editable version).
