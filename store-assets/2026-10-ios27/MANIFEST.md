# Ringbloom — iOS 27 App Store creative set (October 2026)

Prepared on branch `claude/ios27-store-assets` from `origin/main` (`5c67543`). Nothing was uploaded and nothing in App Store Connect was changed. Regenerate with `python3 Tools/compose-ios27-store-assets.py` and `python3 Tools/build-ios27-app-preview.py`.

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

## Screenshots (upload-ready, 5 per set)

Source for every screen: first-party simulator captures in `captures-2026-10/` (iPhone 17 Pro, iOS 27.0, en_GB, 09:41, Ringbloom 1.6 build 12, fresh install). The captures have an alpha channel (fully opaque); they were flattened onto navy and the final PNGs are RGB. Provenance and licence: first-party app captures and the first-party app icon (`ASSET_LICENSES.md`); fonts are Apple's SF Rounded and SF, as in the V3 set, used for App Store promotion of an Apple-platform app. Copies of the five source stills are in `source/`.

| # | File | Source | Caption | Purpose |
|---|---|---|---|---|
| 1 | `01-turn-a-ring-bloom-the-garden.png` | Garden 1 recording at 15.5 s (`ringbloom-garden1-gameplay-19s.mp4`) | TURN A RING. BLOOM THE GARDEN. / One thumb. Three rings. | The hook: two blooms from one turn, real HUD. Works alone in search. |
| 2 | `02-two-ways-to-play.png` | Garden 1 at 7.5 s + `ringbloom-flower-show-class1-card.png` | TWO WAYS TO PLAY / Settle in, or take on a Class. Labels: GARDEN "Endless and calm", FLOWER SHOW "Judged Classes". | Garden vs Flower Show. Wording follows the in-app mode descriptions. |
| 3 | `03-a-new-rule-to-master.png` | `ringbloom-flower-show-class1-card.png` | A NEW RULE TO MASTER / Special rules. Fresh objectives. | Special rules (Ring Harmony). |
| 4 | `04-thirty-classes-to-master.png` | `ringbloom-flower-show-class-book.png` | THIRTY CLASSES TO MASTER / Replay to improve your rating. | Class Book. The "Full Show required" rows state no price. |
| 5 | `05-stuck-take-a-hint.png` | Garden 1 at 4.9 s | STUCK? TAKE A HINT / Hints show which ring to turn. | Garden support feature, shown in the real hint state. |

Upload targets (`en-GB`, ascending order = filename order):
- `screenshots/APP_IPHONE_67-1320x2868/en-GB/` — 6.7" / 6.9" slot (1320x2868). ASC may label this set `APP_IPHONE_67` or 6.9" in the new UI; 1320x2868 is the accepted size.
- `screenshots/APP_IPHONE_65-1242x2688/en-GB/` — 6.5" slot (1242x2688).
- No iPad set (the app does not ship one).

Both sets replace the whole live set (7 each).

### Slot 6: Champion Circuit — NOT included, needs a recapture
No fresh iOS 27 capture of the Champion Circuit exists. The only ones are the live 1.1-era shots (home with "BEST 0 / GARDEN 11", and the dimmed modal), which are the problems above. I did not recycle them. See "Recaptures needed".

## Header and search (creative assets)

Both use the same single idea, **"Turn a ring. Bloom the garden."**, real board from capture #1 (double bloom), the real app icon, and brand art built from the app's own palette (navy, lifted radial glow, coral/saffron/mint/sky accents, concentric rings). No generated imagery.

| File | Size | Notes |
|---|---|---|
| `creative/header-21x9.png` | 3840x1646 | 21:9 header. Icon, headline and board all sit inside the central ~60% (x 768–3072). The real board is the focal point at the right of centre, edge-faded into a medallion; no phone chrome, so nothing else competes. |
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
- Status bar reads 09:41 on every capture. Battery glyph is not charging on class 1 and the Class Book captures but is charging in the Garden 1 recording (simulator artefact). If you want it uniform, recapture all in one session with the override (below).

## Recaptures needed (simulator, one session, one at a time)

Use iPhone 17 Pro Max (6.9", 1320x2868 native) rather than the 17 Pro so the screenshots are native-size, with `xcrun simctl status_bar booted override --time 09:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3`, en_GB, fresh install.

1. **Champion Circuit** (needed for slot 6): a Champion Circuit class in progress or the Circuit class card, with a believable state and no price or "free" text on screen.
2. **Clean Garden 1 stills** at native size: a bloom mid-glow (ideally a double bloom) and a hint state, instead of video frames.
3. **Home screen** with consistent state (for example Best 150, Garden 2, no stale values) if you want a home-screen shot.
4. **Class 30 board at normal width**: in `class30-radiant-take3.mp4` the bottom row (Turn Left / Turn Right) is clipped by the screen edge on an iPhone 17 Pro. That looks like a real layout issue with three objective rows plus the board, not just a capture problem. I did not use it and did not touch app source. Worth checking on device.

## Subtitle proposal (Tom decides; needs a new version)

Live subtitle is "Rotate Rings. Match 3 Petals", which contradicts BRAND.md (never match-three). The live description also opens with "Rotate a ring. Match three petals." and the live promotional text starts "Rotate. Match. Bloom.".

- **Recommended: "Turn rings. Bloom the garden."** (29/30 characters)
- Alternatives: "A calm ring-turning puzzle" (26), "Rotate rings. Bloom petals." (27).

The subtitle can only change with a new version. Suggested description opening to match: "Turn a ring. Bloom the garden." (replace the first line only).

## Promotional text (draft only; can be changed any time without a version)

Live text: "Rotate. Match. Bloom. Play endless Garden and five Flower Show Classes free. No ads. Unlock 25 more Classes and the Champion Circuit with one permanent purchase."

Issues: "Match" conflicts with BRAND.md; "free" and "Unlock" are fine in text but are the purchase wording the creative assets avoid.

Draft (162/170): "Turn a ring. Bloom the garden. Endless Garden and five Flower Show Classes to start, no ads. One permanent purchase adds 25 more Classes and the Champion Circuit."

## Repo metadata drift

Compared the live 1.6 `en-GB` version and app-info localisations against `metadata/version/1.6/en-GB.json` and `metadata/app-info/en-GB.json`: identical, no drift. Fixed instead: `ASSET_LICENSES.md` did not record any of the current store artwork (it only listed 2026-07/08 screenshot paths that no longer exist in the repo); entries for this set are added.

## Optional ChatGPT image prompt (header background)

Not needed to ship (the header above uses no generated art). A painterly garden would add warmth. If the lead runs it, use the result only as a background behind the board; keep the real board and text crisp, and flatten to RGB.

> A wide 21:9 painterly night-garden scene in rich ink-navy, seen from slightly above, softly lit from the centre, with large simplified petals and leaves in coral red, saffron yellow, mint green and sky blue drifting around an empty dark circular clearing in the middle-right of the frame. Calm, tactile, gouache-style texture, soft glows, no text, no letters, no logos, no characters, no hands, no devices, no UI, nothing in the centre of the frame (left 40% mostly dark and quiet for a headline). 3840x1646.

## Next version

`project.yml` is at 1.6 (build 12) and matches the live version. The next release will be **1.7**; create that version in ASC (subtitle, screenshots, preview and header/search all need it or an editable version).
