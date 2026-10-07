# Asset License Log

| Asset file | Type | Source | License | Notes |
|------------|------|--------|---------|-------|
| `Ringbloom/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` | App icon | `gen-image` built-in image generation; prompt recorded in `GAME_DESIGN.md` art direction and run transcript | Commercial output rights | Original, text-free, fully opaque output; resized from 1254×1254 master to 1024×1024. |
| `support-site/icon.png` | Support-site icon | Exact byte-for-byte copy of the generated app icon above | Commercial output rights | Publicly shipped on the GitHub Pages support and privacy site; SHA-256 matches `AppIcon-1024.png`. |
| `Ringbloom/Resources/Audio/rotate.mp3` | SFX | `gen-audio` · ElevenLabs | Commercial output rights | Original soft mechanism notch; generated for this run. |
| `Ringbloom/Resources/Audio/bloom.mp3` | SFX | `gen-audio` · ElevenLabs | Commercial output rights | Original three-note glassy bloom; generated for this run. |
| `Ringbloom/Resources/Audio/win.mp3` | SFX | `gen-audio` · ElevenLabs | Commercial output rights | Original garden-complete chord; generated for this run. |
| `Ringbloom/Resources/Audio/lose.mp3` | SFX | `gen-audio` · ElevenLabs | Commercial output rights | Original gentle round-lost cue; generated for this run. |
| `screenshots/store/en-GB/01-ringbloom-home.png` | App Store screenshot | First-party simulator capture from this build | Original project output | 1284×2778 home screen; captured and uploaded for this run. |
| `screenshots/store/en-GB/02-ringbloom-live.png` | App Store screenshot | First-party simulator capture from this build | Original project output | 1284×2778 live gameplay screen; captured and uploaded for this run. |
| `screenshots/store/en-GB/03-ringbloom-complete.png` | App Store screenshot | First-party simulator capture from this build | Original project output | 1284×2778 completed-garden screen; captured and uploaded for this run. |
| `screenshots/store/en-GB-r2-69/01-rotate-rings.png` | App Store screenshot | First-party iPhone 17 Pro Max simulator capture from the final Round 2 source | Original project output | 1320×2868 live gameplay overview; fresh Round 2 replacement set. |
| `screenshots/store/en-GB-r2-69/02-smart-hint.png` | App Store screenshot | First-party iPhone 17 Pro Max simulator capture from the final Round 2 source | Original project output | 1320×2868 contextual hint state. |
| `screenshots/store/en-GB-r2-69/03-chain-blooms.png` | App Store screenshot | First-party iPhone 17 Pro Max simulator capture from the final Round 2 source | Original project output | 1320×2868 chain-2 scoring state. |
| `screenshots/store/en-GB-r2-69/04-beat-budget.png` | App Store screenshot | First-party iPhone 17 Pro Max simulator capture from the final Round 2 source | Original project output | 1320×2868 Radiant garden-complete result. |
| `screenshots/store/en-GB-r2-69/05-pay-once.png` | App Store screenshot | First-party iPhone 17 Pro Max simulator capture from the final Round 2 source | Original project output | 1320×2868 premium/offline home screen. |
| `screenshots/store/en-GB-r2-65/01-rotate-rings.png` | App Store screenshot | First-party iPhone 14 Plus simulator capture from the final Round 2 source | Original project output | 1284×2778 live gameplay overview for the 6.5-inch slot. |
| `screenshots/store/en-GB-r2-65/02-smart-hint.png` | App Store screenshot | First-party iPhone 14 Plus simulator capture from the final Round 2 source | Original project output | 1284×2778 contextual hint state for the 6.5-inch slot. |
| `screenshots/store/en-GB-r2-65/03-chain-blooms.png` | App Store screenshot | First-party iPhone 14 Plus simulator capture from the final Round 2 source | Original project output | 1284×2778 chain-2 scoring state for the 6.5-inch slot. |
| `screenshots/store/en-GB-r2-65/04-beat-budget.png` | App Store screenshot | First-party iPhone 14 Plus simulator capture from the final Round 2 source | Original project output | 1284×2778 Radiant result for the 6.5-inch slot. |
| `screenshots/store/en-GB-r2-65/05-pay-once.png` | App Store screenshot | First-party iPhone 14 Plus simulator capture from the final Round 2 source | Original project output | 1284×2778 premium/offline home screen for the 6.5-inch slot. |
| `store-assets/2026-10-ios27/source/*.png` | Source captures | First-party iPhone 17 Pro Max simulator captures, iOS 27.0, Ringbloom 1.6 (12) Debug build, 7 Oct 2026 (frames of Simulator recordings: Garden 1 play, Class 1 card, Class Book, Champion Circuit Class 31), native 1320x2868 | Original project output | RGB. Replaces the 2 Oct iPhone 17 Pro stills. |
| `store-assets/2026-10-ios27/screenshots/**` | App Store screenshots | Composed by `Tools/compose-ios27-store-assets.py` around the captures above | Original project output | 1320x2868 and 1242x2688, en-GB, six per set. Apple SF fonts used for App Store promotion. |
| `store-assets/2026-10-ios27/creative/*.png` | Header (21:9) and search (3:2) creative | Same script; real board capture plus `Art/ringbloom-icon-master.png` | Original project output | No generated imagery. |
| `store-assets/2026-10-ios27/preview/*` | App preview and poster | `Tools/build-ios27-app-preview.py` from the Garden 1 recording | Original project output | 886x1920, silent AAC track. |


Source key: `gen-image` · `gen-audio` · `asset-library/<path>` · `download:<url>`
