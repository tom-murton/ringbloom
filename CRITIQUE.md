# Product Critique — Ringbloom 1.0 Baseline

## Verdict

Ringbloom is a complete, attractive small puzzle rather than a broken prototype, but its presentation promises a tactile ring puzzle that the interaction does not yet deliver. The flower is handsome, the rules are coherent, and the win/loss loop works. The central motion, however, is an illusion: a move swaps petal values in fixed slots instead of visibly turning a ring, then replaces blooming petals before the player can see the solved alignment. That single gap makes the game feel flatter and harder to learn than its store pitch suggests.

## First 60 seconds

- The home screen is polished and the primary action is unmistakable. A clean install routes Play through a readable three-step tutorial.
- The tutorial explains the nouns and verbs, but it is passive. It never lets the player rotate a ring, points to no concrete near-match, and does not demonstrate which three petals form a spoke. The first live board therefore presents 24 symbols at once and asks the player to visually parse a new geometry under a move limit.
- The initial instruction, “Choose a ring, then turn it,” teaches input, not strategy. There is no contextual first-move cue, idle hint, or help affordance on the game screen. A new player can understand how to act while still not understanding how to find a productive action.
- Colour-plus-glyph redundancy is strong, but selected-ring emphasis is subtle on the dense board. The chips communicate selection more clearly than the flower itself.

## Game feel and feedback

- **Critical:** the chosen ring does not visibly rotate. `GameBoardView` keeps each petal at a fixed slot and simply receives a new kind after the engine rotates its arrays. The `.animation(value: board)` modifier cannot communicate a 45-degree ring turn when the views themselves never travel around the circle.
- **Critical:** rotation, detection, clear/refill, scoring, and win/loss all commit synchronously. A successful alignment is already gone when the bloom burst starts, so the player cannot visually connect cause, match, and reward.
- The bloom burst is a thin spoke flash with no visible petal pop, scale, or refill cadence. A three-way combo can score 900 and complete most of Garden 1, yet the board settles almost immediately.
- Rotate, bloom, and win sounds can fire back-to-back in one synchronous action. Rapid taps are all accepted, allowing animations and sound cues to pile up instead of preserving a readable action cadence.
- Haptics, four concise sounds, pressed button states, numeric transitions, and outcome cards are good foundations. The problem is sequencing, not total absence of feedback.

## Core loop, rules, and difficulty

- The six-action scan puzzle is internally consistent. Every stable board guarantees at least one scoring move, win-on-last-move is correct, and dead-board repair costs no extra move.
- Garden 1 can be extremely short. In the baseline deterministic play-through, one move produced a 3× simultaneous bloom and 900 points; two more productive moves completed the five-bloom target with 11 moves unused. That is a poor first mastery arc: the player can win before learning to read the board reliably.
- “Combo” means simultaneous spokes, not consecutive skilled play. There is no streak or efficiency reward, so a carefully sustained sequence and a lucky multi-spoke alignment are not distinguished beyond the simultaneous multiplier.
- Difficulty mostly increases the target, introduces the fourth kind at Garden 3, and later removes up to three moves. It does not deliberately shape the opening lesson, stage new concepts, or grade performance.
- Highest Garden is the only progression hook. The home screen always starts that highest garden, so a stuck player cannot revisit an easier garden. Best score has no context, goal, or end-of-round comparison.

## UI, accessibility, and interruptions

- The tested iPhone 17 Pro portrait layout respects safe areas and remains legible. Controls have clear labels and large targets; Dynamic Type and Reduce Motion code paths exist.
- Swipe handling is not genuinely radial. It accepts mostly horizontal drags and maps global left/right to direction regardless of where the gesture begins. A natural tangential swipe can be rejected or feel inverted on the lower half of the ring.
- The Home button immediately abandons the current garden with no confirmation. Returning to Play starts the garden over, so one accidental top-corner tap discards progress.
- Backgrounding is harmless while the process survives, but an in-progress garden is not persisted. Process termination or relaunch restores best/highest values and silently loses the active board, moves, and score.
- VoiceOver exposes a complete clockwise board summary, which is accurate but long. It offers no concise near-match summary or custom rotate actions, so finding the one productive move is much more laborious than for a sighted player.
- A turn-based game does not need a conventional pause timer, but it does need safe leave/resume behaviour. Ringbloom currently has neither a pause sheet nor session restoration.

## Retention and replay

- Retry, Next Garden, local best score, and highest garden provide the minimum replay loop.
- There is no performance grade, perfect-clear badge, streak record, move-efficiency summary, milestone celebration, daily seed, or garden selector. After seeing all four petal kinds, variety is almost entirely numerical.
- Adding a backend, daily service, or Game Center would be scope-heavy. A local streak/efficiency layer and resumable garden would deepen the existing loop without changing the game’s identity.

## Polish and store presentation

- The procedural board, icon, type, palette, and outcome card are coherent and not placeholder-looking.
- The app is silent between discrete actions. That can suit a calm puzzle, so a music loop is not automatically an improvement; stronger layered action cues matter more.
- Existing screenshots are truthful simulator captures, but they show the round-one interaction and do not communicate motion, guidance, or performance mastery. Round two should recapture the improved live and completion states.
- The listing pitch says “crisp one-notch controls” and “luminous bloom animation.” The underlying mechanics work, but the current visual sequence does not fully earn those claims.

## Stability and edge cases observed

- All 20 baseline tests pass. Real simulator paths verified home → tutorial → play → scoring → win → next garden and deliberate loss → retry.
- Fourteen rotation taps at roughly 80 ms spacing did not crash and all were processed. That is structurally safe but visually undesirable: there is no resolution lock, so feedback can overlap and a player can outrun the animation.
- Terminal states correctly reject engine rotations, and the outcome overlay blocks the background controls.
- No frame-rate or memory failure was observed on simulator. The board is small, procedural SwiftUI, and unlikely to be memory-bound; sequencing and interruption safety are the meaningful risks.

## Highest-impact fixes

1. Animate the selected ring through a real 45-degree turn, hold the solved alignment briefly, then burst and refill; lock input during that short resolution sequence.
2. Add contextual, limited hints and a first-garden guided cue so the player learns to read a near-match on the actual board.
3. Reward consecutive productive turns and surface an end-of-garden efficiency result, giving skilled play and replay a visible purpose.
4. Make leaving safe: confirm abandoning an active garden and persist/restore the current session across interruption or termination.
5. Replace the global horizontal swipe rule with geometry-aware tangential rotation, while retaining labelled buttons for predictable accessibility.
