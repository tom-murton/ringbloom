# Flower Show V3 route-blind review

**Verdict: PASS for the route-blind explainability release gate.** All 146 fixtures in scope expose at least two decision/failure contrasts that can be explained from the board and live objectives before the turn, without knowing a future refill.

## Scope

- Campaign Classes 21–30: 10 fixtures.
- Curated Champion Circuit Classes 31–38: 8 fixtures.
- Endless Champion Circuit catalogue: all 128 fixtures (eight roles × 16 variants).

I reviewed the shipped `FlowerShowV3Catalog.json` plus the production board, objective, reducer and visible-status code. I did not read the V3 certification report, solver/reference-route output, tests or route commentary in planning material.

The shipped catalogue loader also accepted content version 3/mapping version 1 and validated all 30 campaign, 8 curated and 128 endless entries, including their scenario digests. Its live mapping resolved Class 21 to `campaign-21`, Class 38 to `circuit-curated-38`, Class 39 to `circuit-r1-v01`, and the last fixture in one full endless cycle to `circuit-r8-v16`.

## Method

For each fixture, I started from its shipped board and used a deterministic, adaptive visible-state audit. At each turn it compared all six legal rotations using only:

- the currently displayed petal colours/shapes and selected ring;
- blooms produced by rotating that visible board;
- the target, moves and live progress for Harmony, Unbroken, Bindweed, Twin Bloom, Prize Bouquet and Judges’ Order;
- infected spokes, the visible Bindweed countdown and its one-turn spread preview.

A witness required two legal moves with different visible consequences and a visible-only reason to prefer or avoid one: immediate blooms, objective progress, a Bindweed clear/spread, preservation of Unbroken, or a wasted move. Hidden refill and repair state were excluded from comparison. After a move, the shipped deterministic refill was applied only to expose the next board; that now-visible board was then assessed afresh.

As a direct leakage check, I replaced the hidden refill cursor with three unrelated values before every inspected decision. None of 882 re-evaluations changed the selected move or comparison move.

## Aggregate result

| Scope | Fixtures passing | Witnesses |
|---|---:|---:|
| Campaign 21–30 | 10 / 10 | 20 |
| Curated Circuit 31–38 | 8 / 8 | 16 |
| Endless Circuit | 128 / 128 | 256 |
| **Total** | **146 / 146** | **292** |

Two witnesses appeared within the first two adaptive turns for 144 fixtures. `circuit-r1-v12` and `circuit-r2-v10` needed a third turn because their opening scoring choices were visibly equivalent, not because the next refill had to be predicted.

The 292 preferred actions all created an immediate visible bloom. They also included 81 Harmony credits, 64 Judges’ Order steps, 74 Unbroken continuations, 61 Bindweed clears, 17 Twin Bloom steps, 178 newly collected Bouquet kinds and 45 multi-bloom turns; categories overlap. In 290 comparisons the avoided move produced no immediate bloom, and 38 of those also visibly broke a live Unbroken chain. Beyond those basic score/no-score failures, 101 fixtures showed at least one scoring-versus-scoring objective trade-off in the short inspected window.

Representative route-blind explanations:

- `campaign-30`, opening board: Inner counter-clockwise visibly makes two blooms, clears two tangled spokes, earns an Inner Double Harmony credit and adds two missing Bouquet kinds; Outer clockwise makes no bloom.
- `circuit-curated-38`, opening board: Inner clockwise visibly scores on the next Judges’ Order ring and adds a missing Bouquet kind; Inner counter-clockwise makes no bloom.
- `circuit-r2-v10`, second visible board: Middle clockwise scores, clears one Bindweed spoke and adds a missing Bouquet kind; Inner clockwise makes no bloom and breaks the live Unbroken chain.

The UI supports these explanations: the board uses redundant colour/shape cues, Bindweed is drawn on affected spokes, the briefing states every active rule, and the in-game rows expose per-ring Harmony credits, current/best Unbroken, Bindweed remaining/countdown, Twin Bloom count, Bouquet kinds and the next Judges’ Order ring.

## Failures and limitation

No fixture failed the stated two-witness criterion.

This is a local route-legibility review, not a shortest-route, completion, difficulty or optimality proof. Most witnesses are deliberately simple score/no-score contrasts. They establish that a player can explain at least two choices or failures without future-refill knowledge; they do not establish that every fixture contains two deep strategic branches.

## Release verdict

**PASS.** There is no route-blind explainability blocker in Classes 21–38 or the 128-fixture endless catalogue. This verdict is limited to the route-blind criterion above and does not replace broader certification or human difficulty judgement.
