# Ringbloom SwiftUI Accessibility Audit — Round 2

Static audit scope: `Ringbloom/Sources/ContentView.swift`, `GameBoardView.swift`, and `Theme.swift` after the Round 2 gameplay changes.

## P0

None found. The complete game route has labelled alternatives to the gesture-only board interaction.

## P1 — physical-device sign-off recommended

- [x] Pause and outcome focus now targets each explicit, semantic heading instead of the containing group (`ContentView.swift:940-997`, `ContentView.swift:1014-1114`). Background gameplay remains hidden while either overlay is present.
- [ ] Verify the final focus timing with VoiceOver on a physical iPhone, including useful restoration after Resume, Retry, and Next Garden. This is a hardware sign-off item, not a known source defect.

## P2 — addressed

- [x] A visually hinted ring now includes “Hinted move” in its accessibility value (`ContentView.swift:532-540`); both direction buttons also expose the hinted state.
- [x] “RINGBLOOM”, “HOW TO BLOOM”, “GARDEN PAUSED”, and the win/loss title are Rotor headings (`ContentView.swift:185-191`, `ContentView.swift:883-888`, `ContentView.swift:950-956`, `ContentView.swift:1031-1039`).
- [x] Decorative Pause and Outcome symbols are hidden from accessibility (`ContentView.swift:944-947`, `ContentView.swift:1025-1028`).
- [x] The outcome chain / move-bonus summary switches to a vertical layout at accessibility text sizes (`ContentView.swift:1017-1022`, `ContentView.swift:1069-1077`).
- [x] Simulator inspection at Accessibility Extra Extra Extra Large plus Increased Contrast found no clipped values or controls; Home and gameplay controls remained reachable through their ScrollViews.

## Addressed in current source

- [x] The board exposes a short header plus eight individually navigable spoke descriptions, instead of a single long board monologue (`GameBoardView.swift:103-114`).
- [x] Each petal has a redundant colour-and-shape description, and visual petals use distinct glyphs as well as colour (`Theme.swift:31-37`, `GameBoardView.swift:211-214`).
- [x] Six labelled ring / rotation buttons provide an accessible alternative to tap and tangential-swipe gestures (`ContentView.swift:515-590`).
- [x] Gameplay is hidden from accessibility while Pause or Outcome is presented (`ContentView.swift:291-345`).
- [x] Primary icon-only controls have meaningful labels and at least 44-point targets (`ContentView.swift:404-465`, `ContentView.swift:868-876`).
- [x] Core gameplay rows switch to vertical layouts for accessibility Dynamic Type sizes and screens scroll where needed (`ContentView.swift:167-260`, `ContentView.swift:364-401`, `ContentView.swift:471-590`, `ContentView.swift:1005-1088`).
- [x] Ring movement, bloom emphasis, and screen / overlay transitions inspect Reduce Motion (`ContentView.swift:14`, `ContentView.swift:270`, `GameBoardView.swift:64`, `GameBoardView.swift:313`).
- [x] Stable accessibility identifiers are present for primary actions and state.

## Manual release verification

- [ ] On a physical iPhone with VoiceOver, complete tutorial → hint → bloom → pause/resume → win → next garden, then loss → retry.
- [x] Request a hint and inspect the accessibility tree. The recommended ring and turn remain discoverable without remembering the one-time announcement.
- [ ] Open Pause and a win/loss outcome from board focus. Expected: focus enters the overlay once, underlying controls disappear, and dismissing it restores useful focus.
- [x] At Accessibility Extra Extra Extra Large plus Increased Contrast, inspect Home and gameplay. No value or control was clipped, and every control remained reachable by scrolling. Outcome uses the same audited adaptive layouts; physical-smallest-device sign-off remains useful.
- [x] With simulator Reduce Motion enabled, make a non-blooming turn. The non-sweeping path resolved normally and decremented the move counter; source inspection confirms bloom and overlay transitions use their reduced-motion branches.
- [ ] With grayscale / colour filters enabled, identify all four petal types, selected ring, hinted move, and bloom state. Expected: glyph, stroke, text, and semantic cues carry every state without colour alone.
- [ ] Exercise Voice Control or Full Keyboard Access. Expected: all primary actions are reachable; no gesture-only step blocks progression.
- [ ] Verify sound-off and haptics-off states, then test bloom / win / loss feedback on hardware.

Regression risk is low for the proposed semantic changes. Overlay-focus changes are moderate risk because they affect focus timing and must be checked across pause, win, loss, retry, next, and dismissal transitions.

---

# Ringbloom SwiftUI Accessibility Audit — Flower Show

Static audit scope: `Ringbloom/Sources/ContentView.swift`, `FlowerShowViews.swift`, `GameBoardView.swift`, and `Theme.swift` after adding the optional Flower Show mode. The Round 2 findings above are retained as the Garden baseline.

## P0

None found. Flower Show uses the same labelled ring-selection and rotation controls as Garden, so its objectives do not introduce a gesture-only route.

## Addressed in the Flower Show source

- [x] Garden and Flower Show are separate heading-labelled mode cards. The locked card exposes the Garden 10 requirement in visible text and as the disabled action's accessibility hint.
- [x] The Flower Show rules screen is scrollable, uses a semantic heading, has labelled 44-point Close and Begin controls, and states the target, move budget, objective rules, and Undo rating consequence.
- [x] Ring Harmony exposes each ring as a separate element with explicit “complete” or “still needed” values. Checkmarks, outlines, text, and VoiceOver values carry completion without relying on colour.
- [x] Unbroken exposes the best chain and required chain as a single labelled progress element, including an explicit completed value.
- [x] Undo has a stable label, availability value, and 44-point target in gameplay; the loss outcome repeats it as a full-width action with a consequence hint.
- [x] Objective progress is included in post-turn announcements, while the persistent progress controls remain discoverable after the announcement ends.
- [x] Flower Show rules, gameplay, pause, win, and loss are all inside ScrollViews where content can grow. The gameplay toolbar switches to two rows at accessibility text sizes, and its iconography uses bounded visual sizes while retaining full semantic labels.
- [x] Flower Show transitions use the existing Reduce Motion branches. New completion states use text and symbols as well as colour.
- [x] Stable accessibility identifiers cover the mode entry, rules, objectives, Undo, and outcome actions.

## Simulator verification — 29 July 2026

- [x] Inspected deterministic Flower Show menu, rules, active class, win, and loss states on an iPhone 13 mini simulator at Accessibility Extra Extra Extra Large with Increased Contrast.
- [x] The first inspection exposed toolbar title/action overflow. The toolbar was changed to an adaptive two-row layout and re-inspected; the mode, class, Undo, Hint, and Sound controls are now distinct and unclipped.
- [x] Rules and objective copy wraps rather than truncates. The Ring Harmony heading was adjusted to avoid mid-word wrapping, and all content remains reachable through scrolling.
- [x] Win and loss outcome cards remain readable at the maximum tested text size; their actions are below the fold but remain in the card's ScrollView.
- [ ] Automated simulator interaction could not be run because the installed Maestro executable has no Java runtime. Deterministic launch states and screenshots were verified, but tap/focus traversal was not automated in this environment.

## Manual release verification

- [ ] On a physical iPhone with VoiceOver, enter Flower Show from Home, read the rules, complete one Harmony mark, use Undo, and finish or lose the class. Confirm useful focus order and announcements at each step.
- [ ] From the loss outcome, activate Undo and confirm VoiceOver returns to the restored game state and announces the Flourishing rating cap.
- [ ] With Voice Control or Full Keyboard Access, confirm the mode card, Close, Begin, ring selectors, rotation controls, Hint, Undo, Sound, Pause, Retry, Next Class, and Home are reachable.
- [ ] With grayscale or colour filters enabled, confirm incomplete and completed Harmony rings, Unbroken progress, selected ring, hinted move, and bloom state remain distinguishable.

Residual accessibility risk is limited to real focus traversal and hardware feedback. Source semantics, deterministic simulator states, Dynamic Type layout, Increased Contrast, and non-colour cues are covered; physical-device sign-off remains recommended before release.

---

# Ringbloom SwiftUI Accessibility Audit — Flower Show Final

Static audit scope: the final 100-class campaign, Champion Circuit, Bindweed, Twin Bloom, progressive rule teaching, Grand Champion outcome, and delayed review-request flow.

## P0

None found. Every Flower Show objective can be completed with the existing labelled ring and rotation controls, and no new state depends on gesture-only input.

## Addressed in the final source

- [x] Bindweed is conveyed by a dotted radial stem and leaf, objective text, a spread countdown, and each affected spoke's VoiceOver value; colour is not the sole cue.
- [x] Twin Bloom exposes a persistent complete/incomplete objective row with text and iconography, rather than relying on transient bloom animation.
- [x] The four first-seen rule introductions are scrollable semantic cards with explicit class, target, move budget, petal kinds, Undo consequence, and a labelled Begin action.
- [x] In-game Rules is always available in Flower Show and dismisses back to the same engine state without restarting the class.
- [x] Objective rows switch to vertical composition at accessibility text sizes. The toolbar, score cards, objective list, board, and controls remain inside a scrollable gameplay surface.
- [x] Class 100 and Grand Champion content use explicit headings and full-width actions; Champion Circuit progress is stated in text on Home.
- [x] The review request has no custom prompt or focus trap. It is attempted only from the successful Garden outcome after a delay while that outcome remains current.

## Simulator verification — 29 July 2026

- [x] Inspected Home, the Bindweed introduction, and a four-objective Class 90 state on an iPhone 13 mini simulator at Accessibility Extra Extra Extra Large with Increased Contrast and Reduce Motion enabled.
- [x] All tested content remains reachable through scrolling. Values and controls wrap or stack instead of truncating, and the four Class 90 objective rows retain text-and-shape status cues.
- [x] Inspected normal-size introductions for Harmony, Unbroken, Bindweed, and Twin Bloom; the complete rule copy and Begin action fit on the iPhone 13 mini.
- [x] Inspected Bindweed before and after its deterministic three-turn spread. The board gains exactly one additional dotted leaf stem and the visible objective resets to “SPREADS IN 3”.
- [x] Inspected the Class 100 Grand Champion outcome and Champion Circuit 101 Home state. Labels distinguish the completed campaign from the continuing circuit.

## Manual release verification

- [ ] On a physical iPhone with VoiceOver, complete each rule introduction, inspect all four objective rows, open and dismiss in-game Rules, then complete Class 100. Confirm useful focus order and restoration.
- [ ] With grayscale or colour filters enabled on hardware, confirm tangled stems remain clearly distinguishable from ring boundaries, spokes, petals, and bloom emphasis.
- [ ] Confirm the delayed native review prompt does not interrupt the bloom animation or initial outcome announcement with VoiceOver running.

Residual accessibility risk is physical VoiceOver focus timing and real-device visual perception of the Bindweed stem. The static semantics, maximum Dynamic Type layout, Increased Contrast, Reduce Motion, and non-colour cues have been audited in the simulator.

---

# Ringbloom SwiftUI Accessibility Audit — Flower Show V3

Static audit scope: the 30-Class campaign, Class Book, Champion Circuit, the compact live objective rail, Bindweed prediction, Prize Bouquet, Double Harmony, Judges' Order, and Flower Show outcomes.

## P0

None found in source or automated simulator traversal. All game actions retain labelled ring and rotation controls; no objective requires a gesture-only route.

## Addressed in the V3 source

- [x] At standard text sizes, every active objective is a separate accessibility element with its complete state. At accessibility sizes, one labelled `GOALS` summary opens a scrollable detail sheet and the turn controls remain together.
- [x] Bindweed state includes the remaining tangled-stem count and spread countdown. The one-turn warning names the exact destination by clock position and does not rely on colour.
- [x] Judges' Order is exposed as one ordered summary, including completed count and the next required ring. Its visual `NEXT` treatment is redundant with text.
- [x] Prize Bouquet, Double Harmony, Twin Bloom and Unbroken use persistent text-and-symbol progress, not transient animation alone.
- [x] Class Book tiles are single Button elements with class, stage, lock/current/completion state, best rating and replay intent in the accessible label or hint.
- [x] Briefings use semantic headings and retain explicit Close/Begin actions. Every new-rule introduction and an ordinary class delta are directly addressable in the UI test tree.
- [x] Turn announcements are derived from the typed reducer transition, so changed progress, spread consequences and remaining moves are not reconstructed from stale UI state.
- [x] The Flower Show result combines milestone and rating in its primary focus target; replay and progression actions have explicit labels.
- [x] Reduce Motion and Increased Contrast branches preserve every late-Class action and state cue.

## Simulator verification — 31 July 2026

- [x] On an iPhone 17 Pro simulator, all 15 Flower Show/Garden UI journeys passed, including all seven rule introductions, ordinary briefing delta, Rosette presentation, Class Book, save replacement, migration, Bindweed state, late HUD and accessibility layout.
- [x] On an iPhone 13 mini simulator, the same 15 journeys passed. This confirms the supported narrow-width layout remains operable.
- [x] Class 30 passed at Accessibility Extra Extra Extra Large with Increased Contrast and Reduce Motion. `GOALS`, all three ring selectors and both rotation controls remained present, and the clockwise action was hittable.
- [x] Class Book tiles appeared as Button elements after the final semantic-trait correction.

## Manual physical-device verification

- [ ] With VoiceOver, traverse Home → Class Book → briefing → play → Goals sheet → result, confirming focus restoration after closing each modal surface.
- [ ] Trigger a Bindweed one-turn warning and spread; confirm the destination announcement is useful and the warning haptic does not interrupt speech.
- [ ] Complete Judges' Order and a simultaneous multi-objective turn; confirm announcements are merged, prioritised and not repetitive.
- [ ] With Voice Control or Full Keyboard Access, complete a turn, request Hint, Undo, pause/resume, replay a completed Class and start a Circuit fixture.
- [ ] With grayscale/colour filters, verify Bindweed, selected ring, hinted move, bloom state, objective completion and rating remain distinguishable.
- [ ] Confirm haptic and sound feedback on hardware, including the sound-off and haptics-off settings.

Residual risk is now confined to physical VoiceOver focus timing, speech/haptic interaction and real-device visual perception. Automated simulator semantics and layout pass, but those hardware checks must not be reported as complete until run on the attached iPhone.

---

# Ringbloom SwiftUI Accessibility Audit — Freemium resilience

Static audit scope: Flower Show Home qualification progress, Class 5 result entitlement checks,
explicit access retry and purchase routing for TOM-57, TOM-59 and TOM-61.

## P0

None found. Checking exposes a disabled semantic action and a separate retry; there is no enabled
control that intentionally discards activation.

## P1 — build-6 physical sign-off pending

- [ ] Verify VoiceOver focus remains on the result surface while access changes from checking to
  full or sample, and that the changed Continue label/value is announced without moving focus to
  hidden gameplay.
- [ ] Execute the complete transition and device matrix in
  `FLOWER_SHOW_UI_ACCESSIBILITY_VERIFICATION_MATRIX.md` with TOM-65.

## P2 — addressed

- [x] Fresh checking exposes `0 of 1 Garden won`; newly-qualified checking exposes `1 of 1` plus
  visible checking copy.
- [x] The result Continue action exposes checking label/value and disabled state; retry is a
  labelled 44-point Button with a stable identifier.
- [x] Result rating semantics remain combined and visible until the player explicitly continues.
- [x] No new animation was introduced, and existing screen transitions retain Reduce Motion paths.

Regression risk is moderate for physical focus timing and low for static labels, values and touch
targets. Automated XCTest cannot replace the pending spoken-focus pass.
