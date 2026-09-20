# Ringbloom agent guide

Ringbloom is a touch puzzle game about arranging petals into blooms. It serves players
looking for calm play in Garden and deliberate scoring challenges in Flower Show.
Preserve the distinction between those modes, readable feedback and fair progression.

## Feedback invitation

Keep the anonymous FeedbackKit form visibly available from Home and permanently available
from Settings. Proactive post-result invitations are optional reminders: retain the persisted
eligibility and cooldown policy, never let it hide either manual entry point, and do not send
feedback text, categories, submission IDs or raw errors to product analytics. The shared
service has no reply channel, so copy must not promise an individual response or that a
suggestion will be built.

## Canonical context

This repository is the product source. The Ringbloom folder in `Gaming Benchmark/` is a
historical run snapshot; do not work from it or automatically copy it over this repository.
`project.yml` and current App Store Connect evidence determine versions and release state.

- `GAME_DESIGN.md` explains the original mechanics.
- `FLOWER_SHOW_FINAL_PLAN.md` and `FREEMIUM_FLOWER_SHOW_IMPLEMENTATION_PLAN.md` explain the
  campaign and access model; use current code and the relevant task for later decisions.
- `Ringbloom/` owns app/game source; `RingbloomTests/` and `RingbloomUITests/` hold checks.
- `ASSET_LICENSES.md` records asset provenance. Preserve the established visual language.

## Verification

`project.yml` generates the Xcode project. After changing its inputs, run `xcodegen generate`.
Discover an available simulator and run the affected tests with:
`xcodebuild test -project Ringbloom.xcodeproj -scheme Ringbloom -destination 'id=<simulator-udid>'`.
Use `Tools/certify-flower-show.sh` when changing authored campaign content or balance;
inspect its generated report rather than treating a build as a certification.

For requested physical testing:
`/Users/tommurton/GitHub/Build-an-app/scripts/test-on-iphone.sh Ringbloom.xcodeproj Ringbloom`.
Report executed tests, skipped checks and the limits of automated gameplay evidence.
For changes to progression, saves or access, verify existing-player and purchase/restore
paths. Show the changed interaction; human enjoyment remains unverified until someone plays.

## Working agreements

Use a task branch; reuse an existing branch/worktree only for the same task. Preserve
unrelated work. Complete the requested scope and relevant checks autonomously; record
additional opportunities without extending the task into indefinite polishing.
Local checks are the default; hosted jobs need a clear benefit and authorisation.
Update affected guidance when this task makes it wrong. Keep current work in the existing
tracker and release facts in project/store evidence, not in this file.
