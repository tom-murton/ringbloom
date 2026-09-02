# Intervention Log — Ringbloom Round 3 · 2026-07-22

## Scored interventions

| # | Time | Phase | Type | Severity | What happened | Artifact / file |
|---|------|-------|------|----------|---------------|-----------------|
| 1 | 16:46 BST | orientation | task-resume | nudge | The original Round 3 prompt was sent on 20 July without an assistant response. The operator had to resend the same prompt on 22 July to start the reporting work. No research, copy, solution, or implementation direction was supplied. | Codex task history · `ringbloom.mdx` |
| 2 | 07:06 BST | publishing | target-correction | nudge | After preparing the story in the wrong website repository and then leaving the correct `personal-cv` page on its write-up-pending fallback, the operator had to state that this model was responsible for the write-up and identify the production route and GitHub/Vercel deployment path. No prose or code was supplied. | `personal-cv/src/content/benchmarks.ts` · `/projects/ship-a-game/ringbloom` |

## Expected human-only steps (NOT scored)

- [x] App Store app record creation (completed before Round 3)
- [x] Final Submit for Review decision (completed before Round 3)
- [ ] Operator and second-player fun check recorded in `PLAYTEST_LOG.md` (not present in the supplied run folder)

## Notes

- The repeated Round 3 prompt is scored because work did not begin until the operator resent it.
- No human supplied article facts, prose, source selection, screenshots, code, credentials, or a technical fix during Round 3.
- The missing human playtest evidence is reported as a methodology gap; no verdict has been inferred.
- The scoring catch-up prompt named the replacement `personal-cv` repository and verification requirements as task scope. The later correction is scored because the prior response incorrectly treated the absent article as outside the catch-up rather than completing and publishing it.

## Tally

nudges: 2  fixes: 0  rescues: 0
