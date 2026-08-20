# Flower Show — implemented campaign plan

## Product shape

Ringbloom keeps two deliberately distinct modes:

- **Garden** is the original calm, endless game. Its simplicity is unchanged.
- **Flower Show** is the judged challenge mode. It unlocks after ten completed
  Gardens, contains 30 curated classes, then continues as the endless Champion
  Circuit from Class 31.

The campaign is short enough for every class to have a visible purpose. It does not
end after Class 30; Class 30 awards Grand Champion and opens the Circuit.

## Campaign

Each five-class stage teaches one idea, develops it, then ends with a Rosette Class.

| Classes | Stage | Purpose |
|---|---|---|
| 1–5 | Harmony Heats | Score with Inner, Middle and Outer rings. |
| 6–10 | Unbroken Heats | Build a scoring chain; a quiet turn resets the current chain. |
| 11–15 | Bindweed Heats | Clear tangled stems before they spread after three uncleared turns. |
| 16–20 | Twin Bloom Heats | Create at least two blooms in one rotation. |
| 21–25 | Judges' Selection | Combine two and three learned rules. |
| 26–30 | Championship | Combine three and four rules under tighter move budgets. |

Classes 5, 10, 15, 20, 25 and 30 award the six campaign rosettes. Class 30 is the
Grand Champion final: ten blooms, four petal kinds, Harmony, Unbroken 4, two starting
Bindweed stems and Twin Bloom.

## Making progression legible

Before every campaign class, the briefing leads with one of:

- `NEW RULE`
- `NEW THIS CLASS`
- `ROSETTE CLASS`
- `GRAND CHAMPION FINAL`

It then names the exact delta from the previous class: a higher bloom target, fewer
moves, another petal kind, a longer chain, another tangled stem or a new rule
combination. Blooms, moves and petal kinds are shown as separate stats. A restrained
short reveal adds anticipation without slowing reduced-motion users.

During play, objective cards show live state rather than hidden progress. In
particular, Unbroken shows the current chain and visibly returns to zero after a quiet
turn. Turn feedback calls out newly completed Twin Bloom, cleared or spreading
Bindweed, Unbroken progress and new Harmony rings.

Winning a class shows every completed rule. Every fifth win awards a numbered
rosette. Completing Class 30 awards Grand Champion and offers Champion Circuit 31.

## Assistance and difficulty

- Garden retains three hints per Garden.
- Flower Show has one hint and one exact undo per Class.
- Undo restores the complete pre-turn state and cannot be used twice.
- The four rules are introduced one at a time at Classes 1, 6, 11 and 16.
- Teaching classes ease the target while retaining the rule; later stages combine
  rules and tighten moves rather than adding currencies, boosters or extra rings.
- Circuit classes are deterministic, varied and capped; endless play must remain
  difficult but solvable rather than scaling into mathematical impossibility.

The balance audit covers all 30 campaign classes across eleven seeds plus 50 Circuit
classes. The rule-aware solver must complete every run without hints or undo. A blind
strategy should fall sharply through the combination and championship stages.

## Save compatibility

This campaign replaces the unreleased 100-class beta layout. The campaign schema is
versioned. On first launch of this build, old Flower Show beta progress is reset so a
tester receives the intended Classes 1–30 sequence and briefings. Garden progress,
scores, streaks, saved Garden state, ratings and preferences are preserved.

## Release checks

Before TestFlight distribution:

1. Run the deterministic balance audit and full unit suite.
2. Run all UI tests on the Simulator, including ordinary class deltas, all four rule
   introductions, Rosette presentation, Bindweed and Champion Circuit state.
3. Repeat the UI suite with Accessibility XXXL text and Increased Contrast.
4. Build and run the project-native physical-iPhone test helper.
5. Archive Release, export and verify the signed IPA before upload.
6. Verify the processed build is attached to both internal and external TestFlight
   groups; external availability may remain subject to Apple's beta review.
