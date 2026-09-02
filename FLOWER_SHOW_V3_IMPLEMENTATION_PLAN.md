# Ringbloom Flower Show v3 - implementation plan

**Status:** independently reviewed, implementation-ready product and technical specification  
**Scope:** Flower Show only; Garden remains the simple, calming, endless "see how far you can get" mode  
**Delivery:** one coherent update, followed by one complete automated, Simulator and physical-iPhone verification pass before internal and external TestFlight distribution  
**Campaign:** 30 curated Classes, then the endless Champion Circuit  
**Save schema:** Flower Show campaign version 3

This document supersedes `FLOWER_SHOW_FINAL_PLAN.md` for the next update. The older file describes the already-built v2 campaign and is historical context only.

---

## 1. Executive decision

Build the complete Flower Show redesign in one update.

Do not add more numbered campaign Classes merely to make the mode longer. Keep the 30-Class campaign, make every Class purposeful, add persistent mastery ratings and replay, and make the Champion Circuit the genuinely endless part.

The current problem is not a shortage of content. It is that many Classes can be cleared by repeatedly taking whichever move gives the largest immediate bloom. The existing Flower Show board repair also manufactures a move that can satisfy several outstanding objectives at once. That makes different rule combinations look substantial in the briefing while feeling almost identical in play.

Version 3 must make the late game harder through visible, understandable decisions:

- take an immediate bloom or prepare a better objective move;
- clear Bindweed now or risk another tangled spoke;
- use the ring needed by the judges or use the ring with the larger bloom;
- complete a missing petal kind or preserve an Unbroken run;
- spend the one Hint or one Undo and accept a lower mastery rating.

The update adds:

1. authored and solver-certified Flower Show boards;
2. an upward sawtooth difficulty curve rather than 30 near-linear target changes;
3. corrected Bindweed pressure;
4. parameterised versions of Harmony and Twin Bloom for late mastery;
5. Prize Bouquet as a new campaign objective;
6. Judges' Order as a Circuit-only expert objective;
7. persistent Seedling, Flourishing and Radiant ratings;
8. a Class Book for replay and rating improvement;
9. an exact objective-aware Hint solver;
10. a bounded endless Circuit selected from a large catalogue of fully prevalidated fixtures rather than unbounded move inflation or runtime-generated puzzles.

Garden is deliberately excluded from all of this.

---

## 2. Product boundaries

### 2.1 Garden

Garden remains:

- the calm, endless original Ringbloom;
- the simple "see how far you can get" experience;
- free of Flower Show objectives;
- on its existing difficulty curve;
- at three Hints per Garden;
- without Undo;
- the route that unlocks Flower Show after ten completed Gardens.

Treat the existing Garden engine, board generation, refill order, RNG algorithm, repair path, Hint selection, scoring, rating, review timing and Codable representation as frozen compatibility code.

Implement v3 gameplay in a separate `FlowerShowEngine`. Production Flower Show turns and the solver must both call one pure `FlowerShowReducer`. Shared immutable vocabulary, `GameBoard` storage and board-rotation primitives may be reused, but Garden must never call the Flower Show reducer, solver, refill or repair path.

Do not change Garden's board generation, scoring, ratings, save behaviour, review-request timing, play UI or completion flow. Prove the boundary with checked-in legacy-save fixtures and deterministic Garden golden tests, not only tests encoded by the new implementation.

### 2.2 Flower Show

Flower Show is:

- the optional judged challenge mode;
- unlocked after ten Garden wins;
- sequential for first completion;
- replayable after a Class has been completed;
- finite and celebratory through Class 30;
- endless through the Champion Circuit from Class 31;
- fully offline, deterministic and free of currencies, adverts or consumable boosters.

### 2.3 Explicit non-goals

Do not add:

- a fourth ring;
- a blanket rule forbidding the same ring twice;
- a blanket rule requiring all rings before any ring can repeat;
- faster two-turn Bindweed;
- time limits;
- lives, tickets, currencies, power-ups or paid boosters;
- a mandatory score target;
- more than the existing four petal kinds;
- hidden adaptive difficulty;
- random unvalidated campaign boards;
- mandatory Flower Show mechanics in Garden.

Double Harmony and Judges' Order deliver the useful ring-planning part of the earlier ring-restriction ideas without turning a simple control into an arbitrary prohibition.

---

## 3. Why this redesign

### 3.1 Evidence from the current build

The current 30-Class build improved explanation and removed the previous 100-Class padding, but its balance harness still shows that an immediate-bloom strategy performs almost as well as the objective-aware strategy in the late campaign:

- Classes 21-25: objective-aware completion 100%; largest-immediate-bloom completion 98%;
- Classes 26-30: objective-aware completion 100%; largest-immediate-bloom completion 95.6%;
- average moves are almost identical between those strategies.

That is the important signal. Random turning fails, but the player is not being asked to make enough meaningful choices once they know how to spot a bloom.

The current objective repair is a major cause. If no single scoring move simultaneously advances all outstanding objectives, the engine reshuffles and can force a move which:

- clears a remaining Bindweed stem;
- makes a Twin Bloom;
- uses an unfinished Harmony ring;
- scores immediately.

The game is therefore protecting the player from the very trade-offs Flower Show is meant to create.

The present Champion Circuit has the opposite problem on paper: it grants 14-16 moves where the campaign final grants 8-9. Its Classes contain more rule labels but can become less demanding immediately after the Grand Champion final.

### 3.2 Design-book check

The plan applies the useful parts of the supplied books:

- Jesse Schell's lenses on challenge and meaningful choice: difficulty should come from decisions whose consequences matter, not from decorative rule count.
- Schell's treatment of simplicity and emergent complexity: retain the three-ring, two-direction verb set and create depth through interactions between a small number of legible goals.
- Schell's puzzle principles: state goals clearly, give continuous progress feedback, avoid solutions which depend on unknowable information, and make the puzzle hard through insight rather than obscurity.
- Schell's interest curves: use rising challenge with short releases, stage climaxes and a stronger final climax rather than a flat ramp.
- Josh Bycer's onboarding, core-loop and late-game phases: Classes 1-20 teach and combine the vocabulary, Classes 21-30 demand mastery, and the Circuit supplies bounded late-game optimisation.

References used:

- Jesse Schell, *The Art of Game Design: A Book of Lenses*, 3rd edition, especially printed pages 217-265 and 297-305.
- Josh Bycer, *Game Design Deep Dive: Free-to-Play*, section 5.5, used only for its onboarding/core/late-game pacing model. Its monetisation recommendations do not apply to Ringbloom.

---

## 4. Experience architecture

The campaign consists of six five-Class stages. Every stage has an internal interest curve:

1. introduce or reframe an idea;
2. practise it with one clear change;
3. combine it with earlier knowledge;
4. add a harder variation or a brief release;
5. finish with a Rosette Class.

The whole campaign has the same shape:

| Classes | Stage | Function |
|---|---|---|
| 1-5 | Harmony Heats | Learn that the ring chosen matters. |
| 6-10 | Unbroken Heats | Learn to plan consecutive scoring turns. |
| 11-15 | Bindweed Trials | Add visible urgency and target prioritisation. |
| 16-20 | Twin Bloom Heats | Learn to construct high-value simultaneous blooms. |
| 21-25 | Bouquet Selection | Add petal-kind mastery and deepen known rules. |
| 26-30 | Championship | Demand synthesis, prioritisation and efficient recovery. |
| 31+ | Champion Circuit | Endless, bounded expert challenges with Judges' Order. |

Every fifth Class awards a numbered Rosette. Class 30 awards Grand Champion. Completing all 30 Classes at Radiant awards the non-gating title **Perfect Show**.

The player never has to earn Radiant to unlock the next Class or the Circuit.

---

## 5. Exact objective rules

All rules are positive goals, not hidden penalties. Every active objective must have a live row during play and a plain-language explanation in the briefing.

### 5.1 Bloom target

The player must create at least the stated number of bloom spokes before moves run out.

- A simultaneous multi-bloom adds every bloomed spoke.
- Reaching the bloom target does not end the Class while another objective remains.
- When the target is met first, show a persistent banner naming the remaining objective or objectives.
- If the final legal move completes the bloom target and all objectives, winning takes precedence over running out of moves.

### 5.2 Ring Harmony

**Briefing copy**

> Score after turning each ring: INNER, MIDDLE and OUTER. Only turns that bloom count; repeats are allowed.

Double Harmony uses:

> Score twice after turning each ring. Only turns that bloom count; repeats are allowed.

Rules:

- A scoring rotation credits the ring which the player rotated.
- One rotation credits that ring once, even when it makes several simultaneous blooms.
- Quiet rotations do not credit a ring.
- Ordinary Harmony requires one credit on each ring.
- Late-game Double Harmony requires two credits on each ring.
- Repeats and any ring order are allowed.

**Live display**

Show three labelled ring tokens with `0/1`, `1/1` or, for Double Harmony, `0/2`, `1/2`, `2/2`.

### 5.3 Unbroken

**Briefing copy**

> Score on N turns in a row. A turn without a bloom resets the run; once achieved, it stays complete.

Rules:

- Each scoring rotation advances the current chain by one turn, regardless of bloom count.
- A quiet rotation resets the current chain to zero.
- The best chain reached during the attempt permanently satisfies the objective, even if a later quiet move breaks the current chain.
- Requirements range from two to five turns.

**Live display**

Show both values, for example `Current run 2 of 5 - best 3`, plus a completed state once the best chain has met the requirement.

### 5.4 Bindweed

**Briefing copy**

> Clear every tangled spoke to win. Bloom on a tangled spoke to clear it. After three turns without a clear, Bindweed spreads to a neighbouring spoke. Clearing any tangled spoke resets the count to three.

Rules:

- A Class begins with one, two or, in late expert Classes, three tangled spokes.
- Every bloom on an infected spoke clears that tangled spoke.
- If a turn clears at least one infected spoke:
  - all remaining Bindweed is preserved;
  - the spread countdown resets to three;
  - if no Bindweed remains, the countdown disappears.
- If a turn clears no Bindweed, the countdown decreases by one whether that turn scored elsewhere or was quiet.
- When the countdown reaches zero, one existing spoke spreads to the deterministic adjacent uninfected spoke previewed on the board, then the countdown resets to three.
- Only one new tangled spoke can be added per spread event.
- Bindweed cannot exceed the eight board spokes.
- All Bindweed must be gone to win, even when the bloom target is already met.

This changes the current build, where clearing one of several tangled spokes does not reset the countdown. The reset makes the rule match the player's natural reading: dealing with the weed buys time; ignoring it creates pressure.

**Live display**

Use the persistent title `CLEAR BINDWEED` and natural-language state such as `2 tangled spokes - spreads after 1 more turn`. At countdown one, show a quiet dashed tendril from the source to the exact next destination; it must not reuse the selected-ring or Hint highlight. VoiceOver names the destination by clock position, for example `Bindweed will spread to 3 o'clock after 1 more turn`. A clear resets the visible countdown with a small positive pulse. A spread gets the existing warning haptic, animated spoke and explicit count increase. Never communicate danger by colour alone.

### 5.5 Twin Bloom

**Briefing copy**

> Create at least two blooms in one turn.

Rules:

- A turn with two or more bloom spokes is one qualifying Twin Bloom turn.
- Three or more simultaneous blooms still count as one qualifying turn.
- Early Classes require one qualifying turn.
- Late Classes can require two qualifying turns.
- Progress, once earned, is permanent for the attempt.

The two-turn upgrade uses:

> Create at least two blooms in one turn, twice. A larger combo still counts as one Twin Bloom.

**Live display**

Show `0/1`, `1/1` or late-game `0/2`, `1/2`, `2/2`.

### 5.6 Prize Bouquet

Prize Bouquet is introduced at Class 21.

**Briefing copy**

> Bloom all four petal kinds: CORAL ●, SAFFRON ◆, MINT ▲ and SKY ✦. They do not need to bloom together. A multi-bloom can collect several kinds at once.

Rules:

- Prize Bouquet is used only in four-petal-kind Classes.
- When a spoke blooms, capture its petal kind before refill and add it to the collected set.
- A simultaneous multi-bloom containing different kinds credits every kind represented.
- Repeated kinds still count towards the general bloom target but do not advance the Bouquet.
- Collected kinds remain complete for the rest of the attempt.

**Live display**

Show four named colour-and-glyph tokens:

- Coral `●`
- Saffron `◆`
- Mint `▲`
- Sky `✦`

Use labels or accessible values as well as colour and shape.

### 5.7 Judges' Order

Judges' Order is introduced in Champion Circuit Class 33, not in the 30-Class campaign.

**Briefing copy**

The sentence includes the actual sequence, for example:

> Score with the rings in this order: INNER, OUTER, MIDDLE. A score with another ring still counts towards blooms and does not reset the order.

Rules:

- The Class supplies a visible sequence of three or four rings.
- Sequences never contain the same ring twice consecutively and contain every ring at least once when length permits.
- A scoring turn using the next required ring advances the sequence by one.
- A quiet turn using that ring does not advance.
- A scoring turn using another ring still counts towards blooms and all other applicable objectives, but does not advance or reset Judges' Order.
- A multi-bloom advances only one step because one ring was rotated.
- Completion is permanent for the attempt.

This is a positive, readable version of ring-order restriction. It creates planning without telling the player that an otherwise valid move is forbidden.

**Live display**

Show the whole ring sequence, visually emphasise the next token, and add a small numbered `NEXT` badge to the relevant ring selector. Keep the selected-ring outline and Hint arrow visually distinct. VoiceOver treats the order as one element and announces, for example, `Judges' Order. Two of four complete. Outer next, then Middle and Inner`.

### 5.8 Objective interaction order

For every rotation, process state in this order:

1. rotate the selected ring and decrement moves;
2. capture bloom spokes and their petal kinds;
3. update streak, bloom count and score;
4. update Harmony, Twin Bloom, Prize Bouquet and Judges' Order from that turn;
5. clear any Bindweed on bloomed spokes;
6. reset, decrement or trigger the Bindweed spread countdown;
7. evaluate all objectives and the bloom target;
8. resolve win before loss on the final move;
9. if still playing, repair only a genuinely dead board.

`TurnResult` must carry enough event data for the UI and VoiceOver to report exactly what happened without trying to reconstruct the previous engine state.

---

## 6. Difficulty model

### 6.1 What "harder" means

Later Classes must not simply display more objective rows. They must increase one or more of:

- planning horizon;
- tension between immediate blooms and objective progress;
- number of goals a single move can help or neglect;
- cost of a quiet setup turn;
- Bindweed urgency;
- efficiency required for Radiant;
- recovery judgement after a suboptimal move.

The base action vocabulary remains six possible rotations: three rings times two directions.

### 6.2 Upward sawtooth

Difficulty rises in waves:

- Classes 1, 6, 11, 16, 21 and Circuit 33 are teaching releases;
- Classes 5, 10, 15, 20 and 25 are stage peaks;
- Class 26 is a small release after a new-mechanic peak, but remains harder than the middle campaign;
- Classes 27-30 rise sharply;
- Class 30 is the strongest campaign climax;
- each eight-Class Circuit lap repeats the same release-to-final shape without unbounded numerical inflation.

### 6.3 Completion budget and Radiant par

Each Class has:

- `moveBudget`: enough for a thoughtful player to recover from one or two imperfect choices;
- `radiantPar`: a solver-certified efficient target which is visibly stated before play.

Rating rules:

- **Seedling:** complete the Class. This is the maximum available after using the Hint.
- **Flourishing:** complete without using the Hint. Undo is allowed, and finishing over the Radiant par earns Flourishing.
- **Radiant:** finish in `radiantPar` moves or fewer with no Hint and no Undo.

Undo can never earn Radiant, even when the restored route finishes within par. A player is never downgraded below Seedling for completing a Class.

Use a separate `FlowerShowRating` type even though the display names match Garden. Do not change or reinterpret `GardenRating`; player-facing Flower Show copy calls this a `Class rating`.

The live HUD always states the best rating still available. It begins at `Radiant possible`, changes immediately to `Best available: Flourishing` after Undo or after the Radiant move allowance is exceeded, and changes to `Best available: Seedling` after Hint. This prevents a result-screen surprise.

For a certified fixture whose shortest route is `L`, `radiantPar` must be `L` or `L + 1`. Use `L + 1` by default. A Rosette, semi-final or final may use `L` only when at least two materially distinct routes achieve it and the efficient choice is perceptible.

### 6.4 Fairness constraints

Every campaign Class, Classes 31-38 and every endless Circuit fixture must:

- have at least two distinct winning routes within the full move budget;
- have at least two winning first actions for Classes 1-20;
- avoid more than two consecutive forced single-answer states from Class 21 onward, including Classes 31-38 and all 128 Circuit catalogue fixtures;
- contain at least one visible objective decision from Class 8 onward;
- contain at least two meaningful decision states from Class 21 onward;
- have a reference solution within `radiantPar`;
- be solvable without a board repair on the reference route;
- have intended choices justified by visible state under the fixed-refill policy in section 12.6;
- never require a Hint or Undo for completion;
- never present more than three special-objective rows at once, excluding the bloom target and move count.

A meaningful decision state is one in which at least two legal moves look locally plausible but differ in objective value, completion viability or final rating. A Class is not considered difficult merely because only one obscure move works.

For certification, a **perceptible meaningful decision** is a state where:

- at least two legal moves score or make an immediately visible objective advance;
- neither move strictly dominates the other across immediate blooms, Bindweed clears, missing Harmony/Bouquet credit, Unbroken continuation, Twin progress and Judges' Order progress;
- the moves lead to different completion viability or best attainable rating under the fixed continuation.

Distinct winning routes must diverge before completion and may not differ only by a symmetry transform or the order of commuting equivalent moves. Classes 21-30, Classes 31-38 and every Circuit fixture require at least two certified perceptible meaningful decisions.

The generated certification report must publish per-Class shortest length, completion slack (`moveBudget - shortestLength`), winning first actions, meaningful decisions, maximum forced-state run, greedy/noisy outcomes and repair count.

A peak `P` exceeds comparator `C` only when:

1. `P` has no more completion slack than `C`;
2. `P` has at least as many certified meaningful decisions as `C`;
3. `P` is strictly harder on at least one of:
   - fewer winning first actions;
   - visible-objective-greedy completion at least 10 percentage points lower;
   - noisy-planner completion at least 10 percentage points lower;
4. no listed strategy has a completion rate more than 5 points higher on `P`.

Apply that directional test to every Rosette versus both its stage opening and immediately preceding Class, Class 25 versus 21, Class 30 versus 26 and 29, and every Circuit final versus both its lap release and immediately preceding fixture.

Solution-graph metrics are necessary but not sufficient. Before release, a fresh agent who has not read the reference routes must inspect/play Classes 21-38 and all 128 Circuit catalogue fixtures from visible state, recording whether each fixture's two certified decisions can be explained without future-refill knowledge. This is one batched final review, not an incremental human approval gate.

---

## 7. Authoritative 30-Class campaign

The values below are the content target. The implementation may change a move budget or Radiant par by one only if the exact solver proves that necessary while selecting the authored board. Any such change must preserve the intended stage curve and be recorded beside the Class fixture.

Abbreviations in the table:

- `H1`: one Harmony credit on each ring;
- `H2`: two Harmony credits on each ring;
- `U4`: Unbroken chain of four scoring turns;
- `W2`: two starting tangled Bindweed spokes;
- `T2`: two qualifying Twin Bloom turns;
- `B`: Prize Bouquet of all four petal kinds.

| Class | Target | Moves | Radiant | Kinds | Special objectives | Exact purpose and authored-board intent |
|---:|---:|---:|---:|---:|---|---|
| 1 | 5 | 9 | 7 | 3 | H1 | Teach that a scoring ring earns Harmony. Opening board offers obvious scores on at least two rings. |
| 2 | 6 | 9 | 7 | 3 | H1 | Clearly announce one more bloom. Tempt repeated use of one productive ring but leave two Harmony routes. |
| 3 | 6 | 8 | 6 | 3 | H1 | Clearly announce one fewer move. First efficiency test; no new vocabulary. |
| 4 | 6 | 8 | 7 | 4 | H1 | Introduce the fourth petal kind and a board with more plausible but non-scoring alignments. |
| 5 | 7 | 8 | 7 | 4 | H1 | Rosette peak. Require ring breadth plus one setup-versus-score decision. |
| 6 | 5 | 8 | 6 | 3 | U2 | Introduce Unbroken alone with a forgiving two-turn requirement. |
| 7 | 6 | 8 | 6 | 3 | U3 | Announce the longer run. Offer an attractive quiet setup which breaks the chain. |
| 8 | 6 | 8 | 7 | 3 | H1 + U2 | First cross-stage combination; ring choice and scoring continuity both matter. |
| 9 | 7 | 9 | 7 | 4 | H1 + U3 | More petal variety and a longer chain, with one extra recovery move. |
| 10 | 7 | 8 | 7 | 4 | H1 + U4 | Rosette peak. The efficient route must plan a four-turn run across all rings. |
| 11 | 5 | 8 | 6 | 3 | W1 | Introduce Bindweed alone. The first tangled spoke has an immediately legible clearing route. |
| 12 | 6 | 8 | 7 | 3 | W1 + H1 | Bring an older rule back immediately so the stage does not repeat the same task five times. |
| 13 | 6 | 8 | 7 | 4 | W1 + U3 | Clearing the weed and preserving the run pull towards different first moves. |
| 14 | 7 | 9 | 8 | 4 | W2 + H1 | Introduce two tangled spokes with one extra move as a small release; clearing one resets the timer. |
| 15 | 8 | 9 | 8 | 4 | W2 + H1 + U3 | Rosette peak. Balance urgency, ring breadth and continuity. |
| 16 | 5 | 8 | 6 | 3 | T1 | Introduce Twin Bloom alone on a board where the double is visible but not the largest-looking alignment. |
| 17 | 6 | 8 | 7 | 3 | T1 + H1 | The Twin's ring may duplicate a Harmony credit, so ordering matters. |
| 18 | 7 | 9 | 7 | 4 | T1 + U3 | The Twin helps the target but counts as only one Unbroken turn. |
| 19 | 7 | 9 | 8 | 4 | T1 + W2 | Choose between setting up the Twin and clearing imminent Bindweed. |
| 20 | 8 | 10 | 8 | 4 | H1 + W2 + T1 | Rosette peak and first three-rule synthesis. Ring breadth, urgency and constructing a Twin compete without a fourth counter. |
| 21 | 6 | 9 | 7 | 4 | B | Introduce Prize Bouquet alone. Every required kind is represented by at least one visible near-bloom. |
| 22 | 7 | 9 | 7 | 4 | B + H1 | Choose ring breadth while collecting missing petal kinds. |
| 23 | 7 | 9 | 8 | 4 | B + W2 | Clearing the urgent tangled spoke may repeat a collected kind; the efficient route plans both. |
| 24 | 7 | 9 | 7 | 4 | H2 | Introduce Double Harmony as deeper mastery of a known rule, not a new control. |
| 25 | 9 | 10 | 8 | 4 | H2 + B + T1 | Rosette peak. A varied Twin can advance the target and Bouquet while six ring credits are still required. |
| 26 | 8 | 9 | 7 | 4 | H1 + T2 | Championship opening and slight release. Explicitly teach the two-Twin upgrade with one familiar companion. |
| 27 | 8 | 10 | 8 | 4 | H1 + U4 + W2 | First Championship pressure test; urgency competes with ring breadth and the planned run. |
| 28 | 9 | 10 | 8 | 4 | B + U4 + W2 | Petal choice, continuity and weed control compete without a decorative fourth objective. |
| 29 | 10 | 10 | 8 | 4 | H2 + U5 + T2 | Precision semi-final. Ten blooms and two Twins must fit into a five-turn scoring run plus limited setup. |
| 30 | 11 | 11 | 9 | 4 | H2 + W3 + B | Grand Champion final. Eleven blooms naturally reward large combos without another counter; ring breadth, three urgent tangled spokes and all four kinds must be coordinated. |

### 7.1 Required briefing delta by Class

Every briefing must name the most important difference from the preceding Class. Use this priority:

1. new rule or new rule depth;
2. new rule combination;
3. changed objective requirement;
4. new petal kind;
5. fewer moves;
6. higher bloom target;
7. deliberate recovery space.

Do not lead with a generic Class title when there is a concrete change to explain.

Examples:

- Class 2: `ONE MORE BLOOM - The judges now want 6. Harmony is unchanged.`
- Class 8: `RULES COMBINE - Complete Ring Harmony while keeping a 2-turn Unbroken run.`
- Class 14: `TWO TANGLED SPOKES - Clearing either one resets the spread countdown to 3.`
- Class 24: `DOUBLE HARMONY - Score with Inner, Middle and Outer twice. Repeats are allowed.`
- Class 30: `GRAND CHAMPION FINAL - Eleven blooms, three tangled spokes, Double Harmony and the full Prize Bouquet.`

---

## 8. Champion Circuit

### 8.1 Purpose

The Circuit is the endless expert mode, not an indefinitely inflating spreadsheet. It must continue to provide difficult but fair Classes without growing targets or move budgets until they become impossible or tedious.

### 8.2 First Circuit lap

Classes 31-38 are curated, use all four petal kinds, and introduce the final objective vocabulary:

| Class | Target | Moves | Radiant | Kinds | Special objectives | Exact Order sequence and purpose |
|---:|---:|---:|---:|---:|---|---|
| 31 | 8 | 10 | 8 | 4 | H1 + B + T1 | Victory-lap release using campaign mastery. |
| 32 | 8 | 10 | 8 | 4 | B + U4 + W2 | Re-establish late-campaign pressure. |
| 33 | 8 | 10 | 8 | 4 | Order 3 | `Inner - Middle - Outer`. One-off teaching release for Judges' Order. |
| 34 | 8 | 10 | 8 | 4 | Order 4 + B | `Outer - Inner - Middle - Outer`. An off-order score can collect a missing Bouquet kind without resetting Order. |
| 35 | 9 | 11 | 9 | 4 | H2 + W2 + T2 | Mid-lap synthesis. |
| 36 | 9 | 10 | 8 | 4 | B + U5 + T1 | Efficiency peak without Bindweed. |
| 37 | 9 | 11 | 9 | 4 | Order 4 + W3 + T2 | `Middle - Outer - Inner - Middle`. Demanding order-versus-urgency decision. |
| 38 | 11 | 12 | 10 | 4 | Order 4 + B + T2 | `Inner - Outer - Middle - Inner`. Circuit Cup final with three legible objectives. |

Judges' Order and Harmony must not appear in the same Class. Both ask the player to track ring use; combining them creates a redundant or confusing counter rather than a new decision.

### 8.3 Endless selection without unvalidated randomness

From Class 39:

1. ship 128 fully materialised, solver-certified Circuit scenarios: 16 variants for each of the eight lap roles;
2. each scenario owns its exact stable board, selected ring, objectives, budgets and fixed refill seed or refill script;
3. runtime must not transform a fixture, derive a new refill seed or generate a new objective/board combination;
4. map a Class number deterministically:
   - `role = (classNumber - 39) % 8`;
   - `variant = ((classNumber - 39) / 8) % 16`;
   - select the exact checked-in fixture at `[role][variant]`;
5. version this mapping and golden-test Classes 39, 46, 47, 166, 167 and a large representative Class number;
6. after the 128 unique fixtures have been used, the catalogue cycles while the displayed Class number continues. Endless means play can continue indefinitely, not that unverified content is invented on the device.

Every exact scenario is certified separately. Do not rely on spoke rotation, mirroring, ring remapping or petal permutation as an assumed symmetry: the current refill-consumption order and Bindweed tie-breaking make those assumptions unsafe. A future release may add more certified fixtures without changing the numerical caps.

Every eight-Class lap follows:

1. expert release;
2. targeted pressure;
3. ordered planning;
4. two-rule interaction;
5. synthesis;
6. efficiency peak;
7. demanding synthesis;
8. lap final.

Circuit caps:

- target blooms: 8-11;
- move budget: 9-12;
- Radiant par: 7-10;
- starting Bindweed: no more than three tangled spokes;
- Unbroken: no more than five;
- Twin Bloom: no more than two qualifying turns;
- Judges' Order: no more than four steps;
- no more than three special-objective rows;

Class numbers continue indefinitely, but numerical difficulty does not rise beyond these caps. Variety comes from objective interactions, board topology and route decisions.

### 8.4 Circuit progression

- Completing Class 30 unlocks Circuit 31 permanently.
- Persist only the next Circuit Class. Derive highest completed as `nextCircuitClass - 1`.
- Losing or leaving a Circuit Class does not drop the player backwards.
- Circuit Classes use the same result-only per-attempt rating rules, but Circuit ratings are not persisted and do not add infinite tiles to the Class Book.
- Home shows `Champion Circuit - Class N`; do not duplicate current and highest when they express the same progress.
- Do not add streak currencies or daily gates.

---

## 9. Briefing, live play and result presentation

### 9.1 Briefing hierarchy

Every Class briefing uses this order:

1. `[STAGE] - CLASS N OF 30`, or `CHAMPION CIRCUIT - CLASS N`;
2. a small contextual badge: `NEW RULE`, `RULE UPGRADE`, `ROSETTE CLASS`, `GRAND CHAMPION FINAL` or `CIRCUIT CUP`;
3. one headline naming the real delta;
4. one explanatory sentence;
5. `TO WIN` with the bloom target and special goals;
6. `N moves - N petal kinds`;
7. `Radiant: N moves or fewer - no Hint - no Undo`;
8. primary `BEGIN CLASS` action.

Remove `THE JUDGES WANT`, repeated Rosette progress and campaign-completion totals from the briefing. Ordinary briefings must fit on one default-size screen on the smallest supported iPhone. Only first-seen rules may require scrolling.

Ordinary briefings appear immediately. Reserve a restrained ribbon flourish for Rosette, Grand Champion and Circuit Cup milestones; keep it under 0.4 seconds and skip it entirely with Reduced Motion. Do not create a modal tutorial after the player has pressed Begin.

### 9.2 New-rule teaching

For the first appearance of each rule:

- show a concise rule card on the briefing;
- include one small board-specific example or highlighted target;
- require one explicit `Got it`/`Begin Class` action;
- store that the introduction was seen;
- always leave the rule accessible from an in-Class info button;
- repeat the complete objective in the live row, not only in the one-time explanation.

The rules introduced at Classes 1, 6, 11, 16, 21, 24 and 33 must each have a dedicated UI test and VoiceOver test.

### 9.3 Live objective rail

The play screen shows:

- blooms completed versus target;
- moves remaining;
- each active special objective;
- the one Hint;
- the one Undo after a move exists.

Flower Show must not show Score because it is not a win or rating condition. It must not show the duplicate global Chain statistic; show chain only inside an active Unbroken objective. These removals are Flower Show-only and must not alter Garden.

Use a compact header such as `6/11 blooms - 5 moves left - Radiant possible`. Keep no more than three special objectives. Keep the board, ring selectors and turn buttons as one contiguous interaction region; at large text sizes, use a two-row control dock so ring selection never requires scrolling away from Turn Left and Turn Right.

Each objective row has:

- symbol;
- short title;
- numeric or token progress;
- completed state;
- accessible label and value;
- a brief non-modal completion pulse.

At Accessibility text sizes, replace the expanded rail with one immediately readable `GOALS` summary button and a short urgent line when required. It opens full objective details in a scrollable sheet, one accessibility element per objective, and returns focus to `GOALS` when dismissed. Do not make the player scroll repeatedly between a goal and the turn controls.

When the bloom target is met but the Class is not won, show:

> BLOOM TARGET MET  
> Still needed: [plain-language list of incomplete objectives].

Generalise the existing Bindweed-specific message so it works for every rule.

### 9.4 Turn feedback

`TurnResult` or a companion event model must identify:

- bloom spokes and kinds;
- Harmony credits gained;
- Unbroken current/best progress;
- Bindweed cleared and whether it spread;
- Twin qualifying turns gained;
- Bouquet kinds gained;
- Judges' Order step gained;
- objectives newly completed.

Use this to announce concise feedback such as:

- `Outer Harmony complete.`
- `Unbroken, 4 of 5.`
- partial clear: `One tangled spoke cleared. One remains. Spread countdown reset to 3.`
- final clear: `All Bindweed cleared.` Do not mention a countdown when none remains.
- `Bindweed spread to 3 o'clock. 3 tangled spokes remain.`
- `Twin Bloom, 1 of 2.`
- `Sky added to Prize Bouquet.`
- `Judges' Order, Middle complete. Outer next.`

Avoid stacking several toast cards. Merge simultaneous progress into one compact event. VoiceOver announces only changed progress, urgent danger and moves remaining; it must not reread every objective after every turn.

### 9.5 Result screen

On completion:

- show `CLASS COMPLETE`, or the combined milestone such as `GRAND CHAMPION - CLASS 30 COMPLETE`;
- show the earned Class rating;
- show moves used versus Radiant par;
- state exactly why the rating was earned;
- show whether this is a new best;
- award a Rosette on Classes 5, 10, 15, 20, 25 and 30;
- award Grand Champion on first completion of Class 30;
- award Perfect Show when all 30 best ratings are Radiant;
- offer the context-appropriate next action.

Rating explanation examples:

- `RADIANT - 8 moves, no Hint, no Undo.`
- `FLOURISHING - Class complete without Hint. Replay in 8 moves or fewer without Undo for Radiant.`
- `SEEDLING - Class complete. Hint used.`

Do not recap every completed objective on success; the completion state already proves them. Focus VoiceOver on the combined milestone and rating, not the rating alone.

Progression completion actions:

- `NEXT CLASS`;
- `ENTER CHAMPION CIRCUIT` after Class 30;
- secondary `CLASS BOOK`.

Replay completion actions:

- `BACK TO CLASS BOOK`;
- secondary `REPLAY CLASS`;
- if the next main-progression Class is incomplete, also offer `CONTINUE CLASS N`.

On failure:

- show `MOVES USED UP`;
- name the remaining work, for example `Still needed: 2 blooms and Outer Harmony`;
- make `UNDO` primary when available, otherwise `TRY AGAIN`;
- keep `HOME` secondary.

---

## 10. Class Book, replay and mastery

### 10.1 Class Book

Add a Flower Show Class Book reachable from the unlocked home card and from result screens.

Layout:

- six named stage sections;
- five Classes per stage, displayed as two-column tiles at ordinary sizes;
- clear locked, current, completed and replayable states;
- the rating name and symbol, never unexplained one/two/three marks alone;
- a Rosette marker on every fifth Class;
- Grand Champion and Perfect Show summary at the top once applicable.

The grid must work at the smallest supported iPhone width without horizontal scrolling. At accessibility sizes use a one-column list. Each tile is one accessibility element, for example `Class 8, Unbroken Heats, completed, best Class rating Flourishing. Replay.`

### 10.2 Progression rules

- The campaign is completed sequentially.
- Completing Class N unlocks N+1.
- Completed Classes can be replayed at any time.
- Starting a replay must not alter the next incomplete Class.
- Completing a replay updates only the best rating if it improves.
- A worse replay never replaces a better rating.
- Class 30 completion, not 30 Radiants, unlocks the Circuit.
- Perfect Show is celebratory only.
- Starting any new campaign, replay or Circuit attempt while another Flower Show attempt is saved must ask before replacing it: `Replace saved Class 18 attempt? Progress in that attempt will be lost.` Actions are `KEEP CLASS 18` and `START CLASS 8`.
- Home and the Class Book identify saved context exactly, for example `RESUME REPLAY - CLASS 8` or `RESUME CIRCUIT - CLASS 42`.
- Returning from a replay restores focus to that Class Book tile.

### 10.3 Home presentation

Before unlock:

> **FLOWER SHOW**  
> Judged puzzle Classes with special rules.  
> Complete 10 Gardens to unlock - N/10.

Campaign in progress:

> **FLOWER SHOW**  
> Class N of 30 - [Stage name]  
> N/30 complete

Campaign complete:

> **GRAND CHAMPION**  
> Champion Circuit - Class N

Keep the card concise and provide separate `CONTINUE`/`RESUME` and `CLASS BOOK` actions. Radiant totals and Perfect Show live inside the Class Book.

---

## 11. Hint, Undo and fair failure

### 11.1 Hint

Flower Show keeps one Hint per attempt.

The current Hint is not sufficient because it returns the immediately scoring move with the highest local objective score. Replace it with an exact completion-aware Hint:

- model the complete engine state, including board, deterministic refill state, every objective, moves and Bindweed timer;
- find a route which completes all objectives and the bloom target within the remaining moves;
- prefer a within-par route when one exists because it teaches the efficient solution, while recognising that presenting any Hint makes the earned rating Seedling;
- otherwise return the shortest completion route;
- use stable deterministic tie-breaking;
- consume the Hint only after a valid move for the unchanged current state is presented.

If no winning route remains:

- do not consume the Hint;
- if Undo is available, say `No winning route remains. Undo the last turn or restart the Class.`;
- otherwise say `No winning route remains. Restart the Class to try a new route.`;
- provide the relevant action beside the message.

Do not silently manufacture a winning move or reshuffle merely because the objectives are inconvenient.

### 11.2 Solver service, concurrency and performance

Define:

```swift
protocol FlowerShowHintSolving: Sendable {
    func solve(_ request: FlowerShowHintRequest) async -> FlowerShowHintResult
}

enum FlowerShowHintResult: Sendable {
    case move(GameMove, routeLength: Int)
    case provenNoRoute
    case timedOut
    case cancelled
}
```

Implement the service as an actor:

- one cancellable task exists per attempt ID and canonical state fingerprint;
- start it after Class start, every committed turn, Undo and resume;
- cancel it on restart, replacement, mode exit or any state mutation;
- cache only an exact result for that exact fingerprint;
- never share a mutable solver cache with Garden.

`GameModel.requestFlowerShowHint()` must:

1. capture the attempt ID and canonical Flower Show search state;
2. await solving off the MainActor;
3. re-enter the MainActor;
4. verify exact attempt ID, state equality, phase and remaining Hint;
5. consume, persist and present only a still-valid `.move`.

Treat stale state, cancellation, timeout and proven no-route as different outcomes. A timeout or cancelled solve must never produce the `No winning route remains` copy and must not consume the Hint.

Show `Considering...` only when a result is not ready. Never freeze ring interaction. Benchmark cold solves separately from cache hits in a Release build on the attached iPhone across every reference-route prefix and all diagnostic rollout states. Targets are under 100 ms median, under 250 ms at the 95th percentile and under 1 second for the worst certified state. Re-author a fixture which breaches the hard limit; do not weaken exactness silently.

### 11.3 Undo

Flower Show keeps one exact Undo per attempt.

Undo must restore:

- board;
- selected ring;
- RNG/refill state;
- score and bloom count;
- moves;
- streak and best streak;
- every objective counter/set/index;
- Bindweed set and timer;
- Hint count and use state as it existed before the undone rotation;
- phase and turn events.

Using Undo permanently disqualifies Radiant for that attempt. Undo remains available after a final-move loss if a snapshot exists.

Undo is available only while phase is `.playing` or `.lost`. It is never available after `.won`. Completion must be committed atomically from the attempt context, the active attempt cleared and an immutable result summary created before the result screen is shown; a won Class cannot return to play or advance twice.

---

## 12. Board authoring and exact solver

### 12.1 Stop using generated openings for campaign content

Each of the 30 campaign Classes, Circuit 31-38 and all 128 endless Circuit catalogue entries must check in:

- a stable scenario ID and content version;
- an explicit stable initial board;
- selected starting ring;
- deterministic refill seed or refill script;
- starting Bindweed spokes;
- full objective definition;
- move budget;
- Radiant par;
- at least one reference Radiant route;
- content notes describing the intended decision.

An explicit board fixture is preferable to relying on `generatedPlayable(seed:)`, because later generator changes must not silently change released puzzle content.

Use one versioned JSON catalogue as the source of truth. Runtime fields contain scenario ID, board, fixed refill source, selected ring, rules and budgets. Authoring-only intent, reference routes, certification metrics and a digest of the runtime content live in a separate generated certification report. Do not maintain competing hand-written Swift and JSON catalogues.

### 12.2 Pure simulation state

Create a pure, hashable `FlowerShowState` containing only gameplay-relevant values:

- board;
- RNG/refill state;
- bloom total;
- moves remaining;
- current and best Unbroken chain;
- fixed-size Harmony credit counts;
- infected Bindweed spokes and spread countdown;
- Twin qualifying-turn count;
- a fixed-size Bouquet bit mask;
- Judges' Order index;
- win/loss state.

All six rotations are solver actions. Ring selection should not be a separate solver action because selecting a ring costs no move.

### 12.3 Solver

Implement one exact solver whose state transitions always call the same pure `FlowerShowReducer` as production:

- campaign fixture certification;
- Circuit template certification;
- the developer balance harness;
- runtime Hint generation.

Requirements:

- deterministic;
- iterative-deepening or equivalent shortest-route search;
- memoised by a canonical key of board, refill state, blooms, moves remaining, current/best streak, objective progress and Bindweed state;
- supports shortest-route search;
- excludes score, selected ring, UI events, Hint state and Undo snapshots from its search key;
- prunes only with formally admissible objective lower bounds;
- returns a route, not only a Boolean;
- can enumerate winning first actions and count distinct routes to a configured cap;
- produces diagnostics explaining why a fixture failed certification.

Safe lower-bound components may include:

- `ceil(remainingBlooms / 8)`;
- the sum of remaining Harmony credits, because one turn credits one rotated ring;
- remaining Judges' Order steps;
- remaining Twin qualifying turns;
- `requiredUnbroken - currentChain` when the best chain is not complete;
- `1` when any Bouquet kind remains;
- `1` when any Bindweed remains.

Combine concurrently achievable objectives with `max`, not `sum`. Remaining Bouquet-kind count is not a move lower bound because one multi-bloom can collect several kinds. Do not use a Bindweed reachability prune unless it has been formally proved admissible.

Compare the pruned solver with an exhaustive unpruned solver over generated reduced-depth states. Any disagreement is a release blocker. The naive depth-12 tree exceeds two billion paths, so a fixture which cannot meet the exact cold-solve performance contract must be re-authored rather than handled with an approximate Hint.

### 12.4 Authoring/search tool

Extend or replace `Tools/FlowerShowSimulation.swift` with a repeatable content pipeline:

1. load each desired Class specification;
2. generate candidate initial boards and refill seeds;
3. reject unstable or immediately bloomed boards;
4. solve exactly;
5. calculate:
   - shortest completion length;
   - winning first-action count;
   - number of distinct routes up to a cap;
   - meaningful decision states;
   - repair count on reference routes;
   - noisy-strategy and greedy-strategy completion;
6. rank candidates against that Class's authored intent;
7. emit the chosen fixture into the versioned JSON source of truth;
8. generate a Markdown balance report for all Classes.

Campaign fixture selection is a build-time content-authoring operation, not runtime randomness.

Create a reproducible macOS command-line authoring target or checked-in runner. The app and tool targets must compile the same pure model, reducer and solver files. Its single documented certification command exits non-zero on any invalid fixture, solver failure, metric failure, digest mismatch or report-generation error.

### 12.5 Board repair

Create a Flower Show-only repair inside the pure reducer:

- if at least one scoring move exists, do not repair or reshuffle;
- if no scoring move exists, reshuffle to a stable board with at least one scoring move;
- do not require the repair move to advance Harmony, Twin Bloom, Bouquet, Judges' Order or Bindweed;
- do not manufacture an objective-perfect move;
- use a stateless deterministic repair derived from the complete canonical Flower Show state plus the scenario's `repairSalt`;
- represent the reshuffle in solver transitions and the typed turn event;
- expose `didReshuffle` for presentation and diagnostics.

Do not modify or call Garden's repair function. The reference route for every authored Class must use zero repairs. In broad noisy play simulations, repairs should be rare and should never be treated as proof that a Class is solvable.

The repair seed/mixing function must be stable across launches and OS versions; do not use Swift's process-randomised `Hasher`. Because repair is a pure function of reducer input and scenario, it requires no hidden mutable repair RNG in state, solver keys, Codable or Undo.

### 12.6 Hidden-refill policy

Flower Show uses a fixed deterministic refill source per certified scenario, but it does not show a large future-petal queue. Adding such a preview would overload the live puzzle. The exact solver may inspect the refill state to prove the real shipped scenario is solvable; this must not be misrepresented as proof that a player could foresee the same route.

Fairness therefore has three separate checks:

1. the omniscient exact solver proves completion, shortest length and par for the one production continuation;
2. a visible-state strategy which is forbidden from reading RNG/refill state must complete the scenario by choosing from the current board and recomputing after every revealed refill;
3. a fresh route-blind reviewer must be able to explain each intended late decision from visible board and objective information.

Reject a candidate when:

- its only winning first move has no visible objective or board rationale;
- its reference explanation relies on a petal which has not appeared;
- the visible-state strategy fails while the omniscient solver succeeds only through refill knowledge;
- there is one narrow winning path dependent on an arbitrary future refill;
- recovery after an ordinary plausible move is impossible solely because of an unseen refill.

No briefing or rating may imply that the player should have predicted a hidden petal. The route is recomputed after each refill appears. This is an explicit fixed-content policy, not a claim of robustness against every counterfactual random refill outcome.

---

## 13. Data model and code organisation

Names can follow project conventions, but the responsibilities below should remain separate.

### 13.1 Objective definition

Use canonical fixed-size values in reducer and solver keys:

```swift
struct RingCredits: Codable, Hashable, Sendable {
    var inner: Int
    var middle: Int
    var outer: Int
}

struct PetalKindMask: OptionSet, Codable, Hashable, Sendable {
    let rawValue: UInt8
}

struct BindweedRequirement: Codable, Hashable, Sendable {
    let startingSpokes: [Int]
    let spreadInterval: Int
}

struct FlowerShowObjectives: Codable, Hashable, Sendable {
    let harmonyCreditsPerRing: Int               // 0...2
    let unbrokenChain: Int?                      // nil or 2...5
    let bindweed: BindweedRequirement?
    let twinBloomTurns: Int                      // 0...2
    let bouquetKinds: PetalKindMask              // empty or all four
    let judgesOrder: [Ring]                      // empty or 3...4

    func validate() throws
}
```

Validation must reject out-of-range values, invalid board dimensions, immediate opening blooms, invalid/duplicate spokes, unavailable petal kinds, `radiantPar > moveBudget`, more than three active objectives and an invalid reference result. Do not silently clamp bad catalogue data.

Rule identity and one-time teaching identity are separate. Class 24 is a distinct rule upgrade:

```swift
enum FlowerShowIntroductionID: String, Codable, Hashable, Sendable {
    case harmony
    case unbroken
    case bindweed
    case twinBloom
    case prizeBouquet
    case doubleHarmony
    case judgesOrder
}
```

### 13.2 Class definition

```swift
struct FlowerShowScenario: Codable, Equatable, Identifiable, Sendable {
    let scenarioID: String
    let scenarioDigest: String
    let initialBoard: GameBoard
    let startingSelectedRing: Ring
    let refillSource: FlowerShowRefillSource
    let repairSalt: UInt64
    let targetBlooms: Int
    let moveBudget: Int
    let radiantPar: Int
    let activeKindCount: Int
    let objectives: FlowerShowObjectives
}

struct ResolvedFlowerShowClass: Equatable, Sendable {
    let displayedClassNumber: Int
    let scenario: FlowerShowScenario
}
```

Scenarios are deliberately numberless because a Circuit fixture can recur under later displayed Class numbers. Campaign/Circuit mapping resolves a displayed number and exact scenario; `FlowerShowAttemptContext.classNumber` is the authority for progression and presentation. The runtime scenario contains no authored commentary or reference solution. Those remain in the certification report keyed by `scenarioID`.

### 13.3 Separate engine and pure reducer

Do not add v3 fields to the frozen Garden `GameEngine`. Add:

```swift
enum FlowerShowReducer {
    static func apply(
        _ move: GameMove,
        to state: FlowerShowState,
        rules: FlowerShowScenario
    ) -> FlowerShowTransition
}

struct FlowerShowEngine: Codable, Equatable, Sendable {
    var attemptID: UUID
    var scenarioID: String
    var scenarioDigest: String
    var state: FlowerShowState
    var hintRemaining: Bool
    var didUseHint: Bool
    var didUseUndo: Bool
    var undoSnapshot: FlowerShowUndoSnapshot?
    var lastTransition: FlowerShowTransition?
}
```

`FlowerShowState` owns fixed-size Harmony credits, Twin-turn count, Bouquet mask, Judges' Order index, Bindweed state and gameplay phase. `FlowerShowEngine` owns assistance and one-step Undo. Both the production path and solver invoke the reducer; there must be no second implementation of Flower Show rule resolution.

The persisted engine stores stable scenario ID and digest, not a second Codable copy of the catalogue scenario. On resume, resolve the ID through the versioned catalogue and reject the active attempt safely when content version or digest no longer matches.

### 13.4 Suggested source split

Avoid making `GameEngine.swift` and `FlowerShow.swift` larger monoliths:

- `FlowerShowModel.swift` - fixed-size state, vocabulary and objective definitions;
- `FlowerShowReducer.swift` - the only gameplay transition implementation;
- `FlowerShowContent.swift` - catalogue loading, validation and Circuit mapping;
- `FlowerShowSolver.swift` - pure state search and route results;
- `FlowerShowProgress.swift` - ratings, progression and migration;
- `FlowerShowBriefingView.swift`;
- `FlowerShowPlayHUD.swift`;
- `FlowerShowClassBookView.swift`;
- `FlowerShowResultView.swift`;
- `Tools/FlowerShowAuthoring.swift` - candidate generation and balance report.

The pure model, reducer and solver files belong to both the app and reproducible authoring targets. UI and persistence files belong only to the app. Reconcile `project.yml` before regenerating the Xcode project.

### 13.5 Engine event model

The reducer returns a complete typed transition rather than making the view compare states:

```swift
struct FlowerShowTransition: Codable, Equatable, Sendable {
    let stateBeforeFingerprint: FlowerShowStateFingerprint
    let stateAfter: FlowerShowState
    let blooms: [BloomEvent]                    // exact (spoke, kind) pairs
    let harmonyBefore: RingCredits
    let harmonyAfter: RingCredits
    let unbrokenBefore: UnbrokenProgress
    let unbrokenAfter: UnbrokenProgress
    let clearedBindweedSpokes: [Int]
    let spreadSourceSpoke: Int?
    let newlyInfectedSpoke: Int?
    let bindweedCountdownBefore: Int?
    let bindweedCountdownAfter: Int?
    let twinTurnsBefore: Int
    let twinTurnsAfter: Int
    let bouquetBefore: PetalKindMask
    let bouquetAfter: PetalKindMask
    let matchedOrderRing: Ring?
    let nextOrderRing: Ring?
    let completedObjectiveIDs: Set<FlowerShowObjectiveID>
    let didReshuffle: Bool
    let phase: GamePhase
}
```

The exact supporting type names can change, but no event may discard spoke-to-kind mapping, spread source/destination, before/after counters or the next required ring. Accessibility announcements and visual feedback consume this one authoritative transition.

---

## 14. Persistence and migration

### 14.1 Persisted Flower Show progress

Use one minimal authoritative model:

```swift
enum FlowerShowAttemptKind: String, Codable, Sendable {
    case campaign
    case replay
    case circuit
}

struct FlowerShowAttemptContext: Codable, Equatable, Sendable {
    let kind: FlowerShowAttemptKind
    let classNumber: Int
}

struct PersistedFlowerShowAttempt: Codable, Equatable, Sendable {
    let contentVersion: Int
    let context: FlowerShowAttemptContext
    let engine: FlowerShowEngine
}

struct FlowerShowResultSummary: Codable, Equatable, Sendable {
    let attemptID: UUID
    let context: FlowerShowAttemptContext
    let rating: FlowerShowRating
    let movesUsed: Int
    let radiantPar: Int
    let didUseHint: Bool
    let didUseUndo: Bool
    let isNewBest: Bool
    let milestone: FlowerShowMilestone?
}

struct FlowerShowProgressV3: Codable, Equatable, Sendable {
    var bestCampaignRatings: [Int: FlowerShowRating]
    var nextCircuitClass: Int
    var activeAttempt: PersistedFlowerShowAttempt?
    var pendingResult: FlowerShowResultSummary?
    var seenIntroductions: Set<FlowerShowIntroductionID>
    var pendingNoticeVersion: Int?
}
```

Derive rather than persist:

- completed campaign Classes from rating keys;
- next incomplete campaign Class as the first missing key in 1...30;
- Grand Champion from campaign completion;
- Perfect Show from 30 Radiant values;
- highest completed Circuit Class as `nextCircuitClass - 1`.

Campaign completion updates or improves the rating, then derives the next Class. Replay may target only a completed campaign Class and may only improve its rating. Circuit attempts must target `nextCircuitClass`; completing Circuit N sets it to N + 1. Circuit ratings are shown on the result but are not persisted.

Best rating ordering is:

`Seedling < Flourishing < Radiant`.

### 14.2 Version 3 migration

This is early TestFlight content, so reset Flower Show progress once rather than pretending the redesigned Classes are equivalent to the old ones.

Decode `flowerShowCampaignVersion` before decoding any Flower Show payload. For campaign version 1 or 2:

- preserve every Garden fact and active Garden exactly;
- preserve settings, sound, haptics and review-request state;
- deliberately skip decoding the obsolete `activeFlowerShow` payload;
- initialise an empty `FlowerShowProgressV3` with `nextCircuitClass = 31`;
- set campaign version to 3;
- set a pending redesign notice;
- persist the migrated save atomically before returning it to the UI;
- show the notice only when Flower Show is next opened:

> **FLOWER SHOW REDESIGNED**  
> Flower Show now has crafted Classes, clearer goals and Class ratings, so Flower Show progress has restarted at Class 1. Your Garden progress and settings are unchanged.

Do not try to decode and temporarily map the old Flower Show definition or Undo snapshot; the whole payload is intentionally discarded. A malformed obsolete Flower Show object must never make top-level Garden decoding fail.

Replace the current `try? decode else .fresh` path with typed load outcomes. A decode failure must never be followed by overwriting the original file with fresh progress. Preserve the original file, report the failure in diagnostics and keep persistence disabled for that in-memory session unless a verified legacy Garden salvage succeeds.

Before the first migrated write, create a recoverable backup of the original progress file. Use atomic replacement. Fresh v3 installs do not receive the redesign notice. Migrated users retain the pending notice until dismissal is persisted. Do not reset Flower Show again on subsequent v3 launches.

Check in raw, hand-held v1 and v2 JSON fixtures which were not produced by the new encoder. They must cover:

- active Garden with `lastTurn`;
- active Flower Show with an Undo snapshot;
- settings and review-request state;
- completed campaign/Circuit progress;
- absent newer keys.

Golden migration tests compare every preserved Garden field and the exact active-Garden continuation after the next deterministic turn.

### 14.3 Replay persistence

An active replay can be resumed after relaunch. Completing it:

- may improve the stored best rating;
- must not move the main campaign pointer;
- must not change the current Circuit Class;
- must not re-award one-time Rosette or Grand Champion celebrations;
- may trigger Perfect Show once, when the final missing Radiant is earned.

Only one Flower Show attempt can be active. Starting another uses the explicit replacement confirmation in section 10. Once a win is committed, clear the active attempt and persist the immutable result in the same MainActor operation; do not leave a resumable won engine.

`pendingResult` makes that atomic result durable across termination. Present it on launch/open before starting another Class. `NEXT CLASS`, `ENTER CHAMPION CIRCUIT`, `BACK TO CLASS BOOK`, `REPLAY CLASS` and an explicit result dismissal first clear and persist `pendingResult`; an attempt ID may be committed only once. One-time Rosette, Grand Champion and Perfect Show presentation comes from the pending summary and is not re-created after dismissal.

---

## 15. Accessibility and presentation requirements

The redesign must retain or improve the existing accessibility standard:

- VoiceOver labels for every ring, direction, objective, rating and progress token;
- VoiceOver announcement after a turn, merged and prioritised;
- Dynamic Type through Accessibility XXXL;
- Increased Contrast;
- Reduce Motion;
- colour-plus-glyph identity for petals;
- minimum 44 by 44 point interactive targets;
- no meaning carried by animation, haptic or colour alone;
- no clipped briefing or result content on the smallest supported iPhone;
- board, ring selectors and turn buttons remain reachable together without scrolling between them;
- every objective is one VoiceOver element with a complete summary rather than separate token stops;
- focus moves to the new-rule heading when a briefing opens;
- focus moves to the combined completion/milestone heading when a result opens;
- Judges' Order exposes the full sequence and current position semantically.

At large text sizes, use the compact Goals summary and details sheet described in section 9 plus a list-form Class Book. Do not shrink text to preserve a decorative grid. Use British player-facing terminology such as `anticlockwise`; call the aid `1 Undo`, not `1 exact Undo`.

---

## 16. Balance and verification plan

The user does not want incremental human gates. Build the coherent redesign, then run one complete final verification programme. Design confidence does not replace regression, solver or device checks.

### 16.1 Exact content certification

Release-blocking:

- exact solver completes all 30 campaign fixtures and Classes 31-38;
- exact solver completes all 128 fully materialised Circuit catalogue fixtures;
- every reference route meets the stored Radiant par;
- every fixture meets the fairness constraints in section 6.4;
- reference routes cause zero board repairs;
- all objective counters and win conditions match the specification;
- catalogue validation and content digest pass;
- Circuit mapping emits only exact catalogue entries and every fixture remains within numerical caps;
- the same Class number always produces the same Class.
- pruned and reduced-depth unpruned solver results agree;
- cold Hint solve time and peak-memory gates pass on the attached iPhone.

### 16.2 Strategy diagnostics

Keep three non-cheating diagnostic agents:

1. **Largest bloom:** selects the move with the most immediate bloom spokes.
2. **Visible objective greedy:** values immediate visible objective progress, then blooms, with no future-state search.
3. **Noisy visible planner:** ranks moves from current visible board/objective information and selects its top move 80% of the time or another non-dominated plausible move 20% of the time. It cannot inspect the refill source or exact-solver route.

Run at least 200 stable tie-break/error rollouts per fixture without overriding production refill sources.

Desired pattern:

- largest-bloom play performs well in Classes 1-5;
- it declines meaningfully through each later stage;
- it completes no more than 40% of rollouts for any individual Class 27-30 and no more than roughly 25% across that band;
- visible-objective greedy completes 45-70% in Classes 21-25 and 25-55% in Classes 26-30;
- noisy visible planning completes 60-85% in Classes 21-25 and 45-75% in Classes 26-30;
- ordinary Circuit fixtures target 30-60% visible-greedy and 45-75% noisy-planner completion;
- Circuit lap finals target 20-45% visible-greedy and 35-65% noisy-planner completion.

These are release-blocking content bands as well as design diagnostics; exact solvability remains separately mandatory. If a greedy strategy again reaches approximately 95% in the Championship, the content has failed even if every rule is technically active. A fixture outside a band must be re-authored or have its budget adjusted within the permitted one-move range; do not waive the result by averaging it with another Class.

Report every metric per Class as well as by stage. Explicitly compare Rosette peaks, Class 25 versus 21, Class 30 versus 26 and 29, and each Circuit final versus its release. Circuit 33 is a one-off teaching release; the Class 39+ eight-role curve has no additional teaching dip.

### 16.3 Unit tests

Add or update tests for:

- all Class definitions and deltas;
- campaign stage and Rosette boundaries;
- the frozen Garden reducer/encoding against raw legacy fixtures and deterministic golden turn sequences;
- every objective independently;
- every pairwise interaction used in campaign content;
- every three-objective Class;
- Bindweed clear-reset, decrement, spread, adjacency and all-eight cap;
- bloom target met while other objectives remain;
- Double Harmony counting;
- two Twin turns;
- mixed-kind simultaneous Bouquet credit;
- Judges' Order correct, wrong-ring, quiet-ring and multi-bloom behaviour;
- final-move win precedence;
- generic dead-board repair only;
- stateless stable repair determinism across repeated runs;
- no objective-perfect forced repair;
- exact Hint route and no-route response;
- timeout and cancellation remaining distinct from proven no-route;
- Hint consumption only on a current valid result;
- stale asynchronous Hint cancellation;
- cold solver performance and state-key canonicalisation;
- exact Undo of every new state field;
- Undo unavailable after win and atomic single completion commit;
- rating rules;
- live best-available-rating transitions;
- rating improvement and non-regression;
- replay not advancing progression;
- active-attempt replacement confirmation and context-specific resume;
- numberless Circuit scenarios resolving to the correct displayed Class after catalogue cycling;
- scenario-digest mismatch invalidating only the active Flower Show attempt;
- pending result durability, one-time dismissal and attempt-ID idempotence;
- Perfect Show;
- all Circuit catalogue fixtures, mapping version and golden Class-number mappings;
- catalogue digest and JSON validation;
- v1/v2 to v3 migration preserving Garden;
- malformed obsolete Flower payload not breaking Garden decode;
- migration saved atomically and notice persisted only after dismissal;
- v3 save round-trip and active replay/Circuit resume.

### 16.4 UI tests

Cover:

- locked Flower Show card and `N/10`;
- unlocked campaign card;
- Class Book at new, partial, Grand Champion and Perfect Show states;
- each rule introduction: 1, 6, 11, 16, 21, 24 and 33;
- ordinary delta briefing;
- each Rosette Class;
- the Twin Bloom two-turn upgrade at Class 26;
- Class 30 briefing, play state and result;
- Bindweed clear, reset, spread and target-met warning;
- Prize Bouquet mixed-kind progress;
- Double Harmony counts;
- Judges' Order next-ring emphasis;
- Hint success and no-route recovery;
- Undo and rating consequence;
- live rating ceiling after Hint, Undo and passing par;
- replay result not advancing progression;
- replacing or retaining a saved attempt;
- Circuit lap final;
- migration notice;
- Garden regression and the review request remaining post-completion only.

Repeat applicable journeys with Accessibility XXXL, Increased Contrast and Reduced Motion.

Classes 20, 30, 33 and 38 must be playable on the smallest supported iPhone and at Accessibility XXXL without repeated scrolling between ring selection and turn controls. Objective summaries, sheets and VoiceOver must remain semantically complete.

### 16.5 Simulator and physical iPhone

Final gate:

1. run the complete Swift test suite;
2. run the balance/content certification tool;
3. run all normal UI journeys on the target Simulator;
4. run accessibility journeys;
5. inspect screenshots for home, Class Book, one normal briefing, each new-rule briefing, late objective rail, Class 30 and Circuit 33;
6. run a Release Simulator build;
7. discover the project and scheme, then run:

   `/Users/tommurton/GitHub/Build-an-app/scripts/test-on-iphone.sh <container> <scheme>`

8. require the helper's final `PHYSICAL_IPHONE_TESTS_PASSED` line;
9. manually inspect touch interaction, haptics, VoiceOver focus, Dynamic Type and performance on the attached unlocked iPhone;
10. have a fresh route-blind agent inspect/play Classes 21-38 and all 128 Circuit catalogue fixtures, and record whether each fixture's certified choices and failures are legible from visible state;
11. reconcile `project.yml` with the current project/build before any Xcode project regeneration;
12. query App Store Connect immediately before archive and choose a strictly higher build number;
13. archive, export and verify the signed build;
14. upload the new build and wait until processing is complete;
15. assign the internal `Test` group and verify `IN_BETA_TESTING`;
16. inspect the existing build-3 external review, then replace or expire it only after the new processed build is ready if Apple requires that to submit the replacement;
17. assign external `Safak`, verify en-GB notes, auto-notify and encryption, and submit the beta build;
18. report the exact external state.

External terminology is strict:

- `WAITING_FOR_REVIEW` means external beta submission is pending, not that external testers can install it;
- external distribution is complete only when the external build state is `IN_BETA_TESTING`;
- a successful upload or group-assignment request is not sufficient evidence.

Do not perform the final production App Store release. That remains Tom's action.

---

## 17. Implementation order

This is sequencing for one update, not a set of incremental release gates.

Before editing, create a recoverable checksum-listed baseline of the current source, project, `project.yml`, tests and save fixtures because this canonical folder has no Git history. Keep it until the new TestFlight state is verified. The current configuration is inconsistent: `project.yml` still records build 2 while the project/release record is build 3. Reconcile both to the verified current App Store Connect state before running project generation, and never allow generation to lower the build number.

### Phase 1 - model and pure rules

1. Freeze Garden with raw-save and deterministic-turn golden tests.
2. Add the separate Flower Show model, engine and pure reducer.
3. Add parameterised objective definitions, rating semantics and exact transition events.
4. Add Flower Show-only Undo, refill and true-dead-board repair.
5. Prove that no Garden production path calls the new reducer or solver.

### Phase 2 - solver and authoring

1. Extract a pure Flower Show simulation state.
2. Implement the exact solver.
3. Implement candidate generation and diagnostics.
4. Select and check in Classes 1-30 and 31-38.
5. Build and certify all 128 materialised Circuit catalogue scenarios.
6. Generate the versioned runtime JSON, content digest and balance report.
7. Add the reproducible non-zero-exit certification command.

### Phase 3 - progression and migration

1. Add persistent best ratings.
2. Separate progression, replay and Circuit attempt context.
3. Add Class Book progression.
4. Add version-first v3 migration, raw legacy fixtures, atomic durability and the Flower Show-only one-time notice.

### Phase 4 - presentation

1. Rebuild the concise briefing hierarchy and milestone-only flourish.
2. Add live rows for all parameterised objectives.
3. Generalise target-met warnings.
4. Add typed turn feedback and VoiceOver announcements.
5. Rebuild result and rating-improvement presentation.
6. Add Class Book and updated home summaries.

### Phase 5 - full verification and TestFlight

1. Run exact certification, tests and diagnostics.
2. Fix every release-blocking failure as one integrated quality pass.
3. Run Simulator and accessibility journeys.
4. Run the physical-iPhone helper and manual device checks.
5. Complete the fresh route-blind late-Class review.
6. Reconcile build configuration, archive, validate, upload and verify the exact internal/external TestFlight states.

---

## 18. Definition of done

The update is done only when all of the following are true:

- Garden remains the current simple, calming, endless mode and its engine, RNG, saves, Hint, scoring, ratings, review timing and play UI pass frozen golden tests.
- Flower Show still unlocks after ten Garden wins and says so clearly.
- No two consecutive campaign Classes have the same objective set, target, budget, petal count and authored decision.
- Every Class briefing names the important change.
- Classes 1-20 teach and recombine rather than repeat.
- Classes 21-30 are measurably harder through decisions, not hidden rules.
- No Class presents more than three special objectives.
- Class 30's 11-bloom final is hard, exact-solver certified and recoverable within its full budget.
- Prize Bouquet, Double Harmony and Judges' Order are fully explained and live-tracked.
- Bindweed clearing visibly buys three turns and remaining Bindweed unmistakably gates completion.
- The objective-perfect repair path no longer exists.
- The one Hint finds a complete route or honestly reports that none remains.
- Timeout, cancellation and stale Hint work are never misreported as no route.
- The one Undo is exact and prevents Radiant for that attempt.
- Best ratings persist and completed Classes can be replayed without damaging progression.
- Class 30 unlocks the Circuit; all 30 Radiants award Perfect Show but gate nothing.
- Circuit difficulty is capped and every runtime Class maps to one of 128 fully materialised, prevalidated catalogue fixtures.
- Raw v1/v2 migrations preserve Garden exactly, are atomically durable and cannot fail because of an obsolete Flower Show payload.
- The fresh route-blind review covers Classes 21-38 and all 128 Circuit catalogue fixtures and confirms that intended choices and failures are legible from visible state.
- Exact content certification, unit tests, UI tests, accessibility checks and Release build pass.
- The attached iPhone run ends with `PHYSICAL_IPHONE_TESTS_PASSED`.
- The uploaded build is verified `IN_BETA_TESTING` internally; the external assignment/submission and its exact state are verified without calling `WAITING_FOR_REVIEW` externally distributed.
- No production App Store release is performed.

---

## 19. Independent review resolution

Three fresh agents reviewed the first complete draft against the current source.

After all substantive findings were resolved, each reviewer performed a blocker-only second pass on 31 July 2026:

- balance and difficulty: **PASS**;
- Swift/engine/persistence architecture: **PASS**;
- simplicity, UX and accessibility: **PASS**.

### Balance review - accepted changes

- removed decorative fourth objectives from Classes 20, 27 and 28;
- made Class 26 the explicit two-Twin teaching release;
- raised Class 30 to 11 blooms while reducing it to three legible objectives;
- removed redundant Order-plus-Harmony combinations;
- added exact Judges' Order sequences and per-Class curve gates;
- added a visible Bindweed spread destination.

### Engineering review - accepted changes

- structurally separated Flower Show from the frozen Garden `GameEngine`;
- added one pure reducer shared by production and the solver;
- replaced unsafe Codable migration with version-first decoding, raw legacy fixtures, atomic persistence and no `.fresh` overwrite on failure;
- replaced unbounded Circuit seeds/transforms with 128 fully materialised certified fixtures;
- made solver keys, admissible pruning, async ownership and Hint result states explicit;
- made progression fields minimal and derived to prevent contradictory saves;
- closed the post-win Undo/double-completion path;
- made build-number and TestFlight state checks exact.

### Simplicity/accessibility review - accepted changes

- capped Classes at three special objectives;
- simplified briefings and reserved flourish for milestones;
- removed Score and duplicate Chain from Flower Show only;
- added live best-available rating language;
- constrained Judges' Order to four steps;
- specified compact Goals presentation, a contiguous control dock and one VoiceOver element per objective;
- simplified results and made saved-attempt replacement explicit;
- moved Radiant totals out of Home and into the Class Book.

### Deliberate adjudications

- No incremental external playtest gate was added because Tom explicitly authorised one coherent expert-led update. One batched fresh route-blind review of Classes 21-38 and every Circuit catalogue fixture remains in the final verification programme.
- No refill-preview queue was added because it would add another live system. The document now states the honest fixed-refill policy: the omniscient solver proves the shipped continuation, a non-clairvoyant visible-state strategy must also win it, and a fresh reviewer must find the intended choices legible.
- Garden receives none of the mechanics proposed by an earlier exploratory review. Its simple endless identity is the immutable boundary for this work.

---

## 20. Instructions for the fresh implementation chat

Use this document as the source of truth.

Before editing:

1. inspect the current source, tests and project file;
2. note that this canonical Ringbloom folder is not currently a Git repository and do not claim commits which do not exist;
3. create the recoverable baseline required in section 17;
4. preserve all unrelated files and the frozen Garden path;
5. create a working plan which maps directly to sections 13-17 above.

Then implement the full v3 design autonomously. Do not stop for approval after each mechanic. Ask Tom only if a genuinely product-changing decision is missing from this specification or an external credential/keychain gate cannot be resolved safely.

Where authored board selection proves that a listed move budget or Radiant par is off by one, use the constrained adjustment allowed in section 7, document the exact reason in the generated balance report, and preserve the intended upward sawtooth.

The implementation chat should finish with:

- a concise description of what changed;
- the final 30-Class content table and any authorised one-move deviations;
- exact test, balance, Simulator and device evidence;
- TestFlight build identifier and verified internal/external state;
- remaining limitations, without overstating the single-player evidence base.
