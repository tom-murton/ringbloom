# Game Design — Ringbloom

## Product

- **Genre:** one-thumb rotational puzzle
- **Audience:** casual puzzle players seeking calm, replayable two-to-five-minute rounds
- **Core loop:** select a concentric petal ring, rotate it one notch, bloom matching radial trios, and fill the garden meter before the move budget runs out.
- **Platform:** iPhone, portrait only, iOS 17+
- **Business model:** paid upfront, target US price $1.99; no ads, tracking, IAP, or subscription

## Rules

1. The board contains three concentric rings, each with eight petals.
2. Every petal has one of four kinds, expressed with both colour and a distinct glyph so play never depends on colour alone.
3. The player selects the inner, middle, or outer ring and rotates it clockwise or counter-clockwise by exactly one slot. Direct swipes on the board and labelled arrow controls perform the same action.
4. After each rotation, every spoke containing three petals of the same kind blooms. Bloomed petals clear and refill; simultaneous blooms increase the combo multiplier.
5. Each rotation costs one move. Reaching the bloom target wins the garden. Running out of moves first loses it.
6. Stable boards are checked for a one-move bloom. If none exists, the board reshuffles automatically without costing a move.
7. Later gardens raise the bloom target and colour pressure within a capped, fair difficulty curve. Score and highest garden persist locally.

## Minimum fun set

- Guaranteed-playable seeded board generation
- Six meaningful actions per turn: three ring choices × two directions
- Animated ring rotation, bloom bursts, particles, haptics, and concise generated SFX
- Score, combo, move budget, bloom meter, win, loss, retry, and next-garden flow
- Short first-play explanation and always-visible accessible controls
- Local best score / highest garden
- Sound and haptic toggles; system Reduce Motion respected
- Deterministic UI-test and screenshot launch modes that do not affect production play

## Deliberate cuts

- No Game Center, backend, login, daily challenge, multiplayer, ads, IAP, subscription, cloud save, social sharing, authored campaign map, narrative, skins, or localization beyond English for version 1.0.
- No iPad target in version 1.0; this keeps layout and screenshot obligations focused.
- No generated character or scene art. The board is procedural, keeping the visual language crisp and license-simple.

## Art direction

“Midnight botanical instrument”: an ink-navy field, three fine concentric guide rings, soft luminous petals in coral, saffron, mint, and sky blue, and warm ivory bloom sparks. Rounded native typography stays restrained; each colour owns a glyph. The icon uses the same concentric flower language with no text and no baked corner radius.

## Audio direction

Four short commercial-clear generated sounds: a soft wooden notch for rotation, glassy three-note bloom, warm garden-complete chord, and gentle low seed-drop for a missed garden. No looping music in 1.0, keeping the calm game comfortable in short sessions and the binary small.

## Accessibility

- Colour is redundant with glyph shape and VoiceOver labels.
- All controls use at least 44-point targets and stable accessibility identifiers.
- VoiceOver announces selected ring, moves, bloom progress, score, and outcomes.
- Reduce Motion replaces sweeping/burst transitions with fades and scale restraint.
- Haptics and sound can be disabled independently.

## Verification contract

- Unit tests cover rotation, bloom detection, scoring, win, loss, and playable-board repair.
- Simulator verification must demonstrate: launch → start → select/rotate → score and bloom progress change → win → next/replay, plus a loss → retry path.
- Store screenshots use real simulator renders of the menu, live play, and completed-garden states.

